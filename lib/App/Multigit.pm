package App::Multigit;

use 5.014;
use strict;
use warnings FATAL => 'all';

use List::UtilsBy qw(sort_by);
use Capture::Tiny qw(capture);
use File::Find::Rule;
use Future::Utils qw(fmap);
use Path::Class;
use Config::INI::Reader;
use Config::INI::Writer;
use IPC::Run;
use Try::Tiny;

use App::Multigit::Repo;
use App::Multigit::Loop qw(loop);

use Exporter 'import';

our @EXPORT_OK = qw/
    mgconfig mg_parent all_repositories 
    base_branch set_base_branch mg_each
/;

=head1 NAME

App::Multigit - Run commands on a bunch of git repositories without having to
deal with git subrepositories.

=cut

our $VERSION = '0.09';

=head1 PACKAGE VARS

=head2 %BEHAVIOUR

This holds configuration set by options passed to the C<mg> script itself.

Observe that C<mg [options] command [command-options]> will pass C<options> to
C<mg>, and C<command-options> to C<mg-command>. It is those C<options> that will
affect C<%BEHAVIOUR>.

Scripts may also therefore change C<%BEHAVIOUR> themselves, but it is probably
badly behaved to do so.

=head3 report_on_no_output

Defaults to true; this should be used by scripts to determine whether to bother
mentioning repositories that gave no output at all for the given task. If you
use C<App::Multigit::Repo::report>, this will be honoured by default.

Controlled by the C<MG_REPORT_ON_NO_OUTPUT> environment variable.

=head3 ignore_stdout, ignore_stderr

These default to false, and will black-hole these streams wherever we have
control to do so.

Controlled by the C<MG_IGNORE_{STDOUT,STDERR}> environment variables.

=head3 concurrent_processes

Number of processes to run in parallel. Defaults to 20.

Controlled by the C<MG_CONCURRENT_PROCESSES> environment variable.

=head3 skip_readonly

Do nothing to repositories that have C<readonly = 1> set in C<.mgconfig>.

Controlled by the C<MG_SKIP_READONLY> environment variable.

=cut

our %BEHAVIOUR = (
    report_on_no_output => $ENV{MG_REPORT_ON_NO_OUTPUT} // 1,
    ignore_stdout       => !!$ENV{MG_IGNORE_STDOUT},
    ignore_stderr       => !!$ENV{MG_IGNORE_STDERR},
    concurrent          => $ENV{MG_CONCURRENT_PROCESSES} // 20,
    skip_readonly       => !!$ENV{MG_SKIP_READONLY},
);

=head1 FUNCTIONS

These are not currently exported.

=head2 mgconfig

Returns C<.mgconfig>. This is a stub to be later configurable, but also
to stop me typoing it all the time.

=cut

sub mgconfig() {
    return '.mgconfig';
}

=head2 mg_parent

Tries to find the closest directory with an C<mgconfig> in it. Dies if there is
no mgconfig here.

=cut

sub mg_parent {
    my $pwd = shift // dir->absolute;

    PARENT: {
        do {
            return $pwd if -e $pwd->file(mgconfig);
            last PARENT if $pwd eq $pwd->parent;
        }
        while ($pwd = $pwd->parent);
    }

    die "Could not find .mgconfig in any parent directory";
}

=head2 all_repositories

Returns a hashref of all repositories under C<mg_parent>.

The keys are the repository directories relative to C<mg_parent>, and the values
are the hashrefs from the config, if any.

=cut

sub all_repositories {
    my $pwd = shift // dir->absolute;
    my $mg_parent = mg_parent $pwd;

    my $cfg = Config::INI::Reader->read_file($mg_parent->file(mgconfig));

    for (keys %$cfg) {
        $cfg->{$_}->{dir} //= dir($_)->basename =~ s/\.git$//r;
        $cfg->{$_}->{url} //= $_;
    }

    return $cfg;
}

=head2 each($command)

For each configured repository, C<$command> will be run. Each command is run in
a separate process which C<chdir>s into the repository first.

It returns a convergent L<Future> that represents all tasks. When this Future
completes, all tasks are complete.

In the arrayref form, the C<$command> is passed directly to C<run> in
L<App::Multigit::Repo>.  The Futures returned thus are collated and the list of
return values is thus collated. The list will be an alternating list of STDOUT
and STDERRs from the commands thus run.

    my $future = App::Multigit::each([qw/git reset --hard HEAD/]);
    my @stdios = $future->get;

The subref form is more useful. The subref is run with the Repo object, allowing
you to chain functionality thus.
    
    use curry;
    my $future = App::Multigit::each(sub {
        my $repo = shift;
        $repo
            ->run(\&do_a_thing)
            ->then($repo->curry::run(\&do_another_thing))
        ;
    });

In this case, the subref given to C<run> is passed the STDOUT and STDERR from
the previous command; for convenience, they start out as the empty strings,
rather than C<undef>.

    sub do_a_thing {
        my ($repo_obj, $stdout, $stderr) = @_;
        ...
    }

Thus you can chain them in any order.

Observe also that the interface to C<run> allows for the arrayref form as well:

    use curry;
    my $future = App::Multigit::each(sub {
        my $repo = shift;
        $repo
            ->run([qw/git checkout master/])
            ->then($repo->curry::run(\&do_another_thing))
        ;
    });

Notably, the returned Future will gather the return values of all the other Futures.
This means your final C<< ->then >> can be something other than a curried
C<run>. The helper function C<report> produces a pair whose first value is the
repo name and the second value is STDOUT concatenated with STDERR.

    use curry;
    my $future = App::Multigit::each(sub {
        my $repo = shift;
        $repo
            ->run([qw/git checkout master/])
            ->then($repo->curry::run(\&do_another_thing))
            ->then(App::Multigit::report($repo))
        ;
    });

    my %results = $future->get;

=cut

sub each {
    my $command = shift;
    my $repos = all_repositories;

    return fmap { _run_in_repo($command, $_[0], $repos->{$_[0]}) } 
        foreach => [ keys %$repos ],
        concurrent => $BEHAVIOUR{concurrent_processes},
    ;
}

=head2 mg_each

This is the exported name of C<each>

    use App::Multigit qw/mg_each/;

=cut

*mg_each = \&each;

sub _run_in_repo {
    my ($cmd, $repo, $config) = @_;

    return Future->done( $config->{dir} => "Readonly" )
        if $BEHAVIOUR{skip_readonly} and $config->{readonly};

    if (ref $cmd eq 'ARRAY') {
        App::Multigit::Repo->new(
            name => $repo,
            config => $config
        )->run($cmd);
    }
    else {
        App::Multigit::Repo->new(
            name => $repo,
            config => $config
        )->$cmd;
    }
}

=head2 loop

Returns the L<IO::Async::Loop> object. This is essentially a singleton.

=cut

# sub loop used to be here but I moved it.

=head2 init($workdir)

Scans C<$workdir> for git directories and registers each in C<.mgconfig>

=cut

sub init {
    my $workdir = shift;
    my @dirs = File::Find::Rule
        ->relative
        ->directory
        ->not_name('.git')
        ->maxdepth(1)
        ->mindepth(1)
        ->in($workdir);

    my %config;

    # If it's already inited, we'll keep the config
    %config = try {
        %{ all_repositories() }
    } catch {};

    for my $dir (@dirs) {
        my ($remotes) = capture {
            system qw(git -C), $dir, qw(remote -v)
                and return;
        };

        # FIXME: This seems fragile
        next if $?;

        if (not $remotes) {
            warn "No remotes configured for $dir\n";
            next;
        }
        my ($first_remote) = split /\n/, $remotes;
        my ($name, $url) = split ' ', $first_remote;

        $config{$url}->{dir} = $dir;
    }

    
    my $config_filename = dir($workdir)->file(mgconfig);
    Config::INI::Writer->write_file(\%config, $config_filename);
}

=head2 base_branch

Returns the branch that the base repository is on; i.e. the repository that
contains the C<.mgconfig> or equivalent.

The purpose of this is to switch the entire project onto a feature branch;
scripts can use this as the cue to work against a branch other than master.

This will die if the base repository is not on a branch, because if you've asked
for it, giving you a default will more likely be a hindrance than a help.

=cut

sub base_branch() {
    my $dir = mg_parent;

    my ($stdout) = capture {
        system qw(git -C), $dir, qw(branch)
    };

    my ($branch) = $stdout =~ /\* (.+)/;
    return $branch if $branch;

    die "The base repository is not on a branch!";
}

=head2 set_base_branch($branch)

Checks out the provided branch name on the parent repository

=cut

sub set_base_branch {
    my $base_branch = shift;

    my ($stdout, $stderr) = capture {
        system qw(git -C), mg_parent, qw(checkout -B), $base_branch
    };
}

1;

__END__

=head1 AUTHOR

Alastair McGowan-Douglas, C<< <altreus at perl.org> >>

=head1 ACKNOWLEDGEMENTS

This module could have been a lot simpler but I wanted it to be a foray into the
world of Futures.  Shout outs go to those cats in irc.freenode.net#perl who
basically architectured this for me.

=over

=item tm604 (TEAM) - for actually understanding Future architecture, and not
being mad at me.

=item LeoNerd (PEVANS) - also for not being irritated by my inane questions
about IO::Async and Future.

=back

=head1 BUGS

Please report bugs on the github repository L<https://github.com/Altreus/App-Multigit>.

=head1 LICENSE

Copyright 2015 Alastair McGowan-Douglas.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

