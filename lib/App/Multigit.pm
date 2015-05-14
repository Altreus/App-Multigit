package App::Multigit;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Capture::Tiny qw(capture);
use File::Find::Rule;
use Path::Class;
use Config::Any;
use IO::Async::Loop;
use IO::Async::Process;
use IPC::Run;
use Safe::Isa;

=head1 NAME

App::Multigit - Run commands on a bunch of git repositories without having to
deal with git subrepositories.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

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

    my $cfg = Config::Any->load_files({
        files => [ mgconfig ],
        use_ext => 0,
        force_plugins => [
            qw/Config::Any::INI/
        ]
    });

    my $repos = +{
        map { %$_ } values %{ $cfg->[0] }
    };

    for (keys %$repos) {
        $repos->{$_}->{dir} //= dir($_)->basename =~ s/\.git$//r
    }

    return $repos;
}

=head2 each($command)

For each configured repository, C<$command> will be run. Each command is run in
a separate process which C<chdir>s into the repository first.

C<$command> can be either a subref or an arrayref. If a subref, it is called
with no parameters; if an arrayref, it is used as a system command. See
L<IO::Async::Process> for the C<code> and C<command> arguments.

It returns an array of L<Future> objects, one for each repository.

    my @futures = App::Multigit::each([qw/git reset --hard HEAD/]);

The Futures yield several values:

=over

=item C<$repo> - The URL to the repository's remote, i.e. the key in the config file

=item C<$config> - The rest of the config for this repo, including the C<dir>
key, which will be the directory relative to the mg root.

=item C<$pid>, C<$exitcode>, C<$stdout>, C<$stderr> - These are all from the
subprocess that was run. See C<run_child> in L<IO::Async::Loop>.

=back

See the examples directory for two scripts that use the yielded values. It
probably won't be much use to use the yielded values directly, because you'll
get a huge list with no boundaries. (Well, I guess you could chop it up into
sixes). The C<< ->then >> pattern in the examples works better.

=cut

sub each {
    my $command = shift;
    my $repos = all_repositories;

    my @futures;
    for my $repo (keys %$repos) {
        my $future = loop()->new_future;
        my %child;

        if (ref $command eq 'CODE') {
            loop()->run_child(
                code => sub {
                    chdir $repos->{$repo}->{dir};
                    $command->()
                },
                on_finish => sub {
                    $future->done($repo, $repos->{$repo}, @_)
                }
            );
        }
        else {
            my ($stdout, $stderr);
            loop()->add(
                IO::Async::Process->new(
                    code => sub {
                        chdir $repos->{$repo}->{dir};
                        IPC::Run::run($command);
                    },
                    stdout => { into => \$stdout },
                    stderr => { into => \$stderr },
                    on_finish => sub {
                        my ($process, $exitcode) = @_;
                        $future->done($repo, $repos->{$repo}, $process->pid, $exitcode, $stdout, $stderr );
                    }
                )
            );
        }

        push @futures, $future;
    }

    return @futures;
}

=head2 loop

Returns the L<IO::Async::Loop> object. This is essentially a singleton.

=cut

sub loop {
    state $loop = IO::Async::Loop->new;
    $loop;
}

=head2 init($workdir)

Scans C<$workdir> for git directories and registers each in C<.mgconfig>

=cut

sub init {
    my $workdir = shift;
    my @dirs = File::Find::Rule
        ->relative
        ->directory
        ->maxdepth(1)
        ->mindepth(1)
        ->in($workdir);

    my %config;
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

        $config{$url} = $dir;
    }

    {
        my $config_filename = dir($workdir)->file(App::Multigit::mgconfig);
        open my $config_out, ">", $config_filename;

        for (keys %config) {
            say $config_out "[$_]";
            say $config_out "dir=$config{$_}";
        }
    }
}
1;

__END__

=head1 AUTHOR

Alastair McGowan-Douglas, C<< <altreus at perl.org> >>

=head1 BUGS

Please report bugs on the github repository L<https://github.com/Altreus/App-Multigit>.

=head1 LICENSE

Copyright 2014 Alastair McGowan-Douglas.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

