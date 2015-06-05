package App::Multigit::Repo;

use App::Multigit::Loop qw(loop);
use IO::Async::Process;
use Moo;
use Cwd 'getcwd';

use 5.014;

=head1 NAME

App::Multigit::Repo - Moo class to represent a repo

=head1 DESCRIPTION

Holds the name and config for a repo, to make future chaining code cleaner.

You can curry objects is what I mean.

=head1 PROPERTIES

=head2 name

Name as in the key from the mgconfig file that defines this repo. As in, the
URL.

It's called name because it doesn't have to be the URL, but is by default.

=cut

has name => (
    is => 'ro',
);

=head2 config

The config from the mgconfig file for this repo.

This is given a C<dir> key if the config does not already specify one.

=cut

has config => (
    is => 'ro',
);

=head1 METHODS

=head2 run($command, [$stdout, [$stderr]])

Run a command, passing C<$stdout> and C<$stderr> to it.

If the command is a CODE ref, it is run with this Repo object, C<$stdout>, and
C<$stderr>. The CODE reference should use normal print/say/warn/die behaviour.
Its return value is discarded.

If it is an ARRAY ref, it is run with IO::Async::Process, with C<$stdout> sent
to the process's STDIN. C<$stderr> is lost.

The process returns a Future that yields a new pair of STDOUT and STDERR
strings.

=cut

sub run {
    my ($self, $command, $past_stdout, $past_stderr) = @_;
    my $future = loop->new_future;

    $past_stdout //= '';
    $past_stderr //= '';

    if (ref $command eq 'CODE') {
        loop->run_child(
            code => sub {
                chdir $self->config->{dir};
                $self->$command($past_stdout, $past_stderr)
            },
            on_finish => sub {
                my (undef, undef, $stdout, $stderr) = @_;
                $future->done($stdout, $stderr)
            }
        );
    }
    else {
        my ($stdout, $stderr);
        loop->add(
            IO::Async::Process->new(
                code => sub {
                    chdir $self->config->{dir};
                    IPC::Run::run($command);
                },
                stdin => { from => $past_stdout },
                stdout => { into => \$stdout },
                stderr => { into => \$stderr },
                on_finish => sub {
                    $future->done($stdout, $stderr);
                }
            )
        );
    }
    return $future;
}

1;

__END__

=head1 AUTHOR

Alastair McGowan-Douglas, C<< <altreus at perl.org> >>

=head1 BUGS

Please report bugs on the github repository L<https://github.com/Altreus/App-Multigit>.

=head1 LICENSE

Copyright 2015 Alastair McGowan-Douglas.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>
