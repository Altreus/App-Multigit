package App::Multigit;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Path::Class;
use Config::Any;
use IO::Async::Loop;
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

    do {
        return $pwd if -e $pwd->file(mgconfig);
        last if $pwd eq $pwd->parent;
    }
    while ($pwd = $pwd->parent);

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
        map { %$_ } values $cfg->[0]
    };

    for (keys $repos) {
        $repos{$_}->{dir} //= dir($_)->basename =~ s/\.git$//r
    }

    return $repos;
}

=head2 each($subref)

For each configured repository, C<$subref> will be run.

Its first argument will be a L<Future> object; its second argument will be the
repository URL; and its third argument will be the configuration for that
repository.

The subref should return a subclass of L<IO::Async::Notifier>, which will be
added to an L<IO::Async> loop.

It returns the array of L<Future> objects.

    # tableflip all the things
    my @futures =
    App::Multigit::each(
        sub {
            my ($future, $repo, $config) = @_;
            my $output_buffer;
            IO::Async::Process->new(
                command => [ 'git', '--work-tree='.$repo, qw/reset --hard HEAD/ ]
                stdout => {
                    into => \$output_buffer,
                },
                on_finish => sub {
                    chomp $output_buffer;
                    $future->done($output_buffer);
                },
                on_exception => sub {
                    my $errno = shift;
                    say "$dir: error";
                    $future->fail($errno);
                }
            )
        }
    );

    # block til they're all done
    my @output = Future->needs_all(@futures)->get;

=cut

sub each {
    my $subref = shift;
    my $repos = all_repositories;

    my @futures;
    for my $repo (keys $repos) {
        my $future = loop->new_future;
        loop->add($subref->($future));

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

