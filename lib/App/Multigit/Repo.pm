package App::Multigit::Repo;

use App::Multigit::Loop qw(loop);
use IO::Async::Process;
use Future;
use Moo;
use Cwd 'getcwd';

use 5.014;

our $VERSION = '0.06';

=encoding utf8

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

=head2 run($command, [%data])

Run a command, in one of two ways:

If the command is a CODE ref, it is run with this Repo object, and the entirety
of C<%data>. The CODE reference should use normal print/say/warn/die behaviour.
Its return value is discarded. If the subref returns at all, it is considered to
have succeeded.

If it is an ARRAY ref, it is run with IO::Async::Process, with C<stdout> sent
to the process's STDIN.

A Future object is returned. When the command finishes, the Future is completed
with a hash-shaped list identical to the one C<run> accepts.

=head3 data

C<run> accepts a hash of data. If C<stdout> or C<stderr> are provided here, the
Future will have these values in C<past_stdout> and C<past_stderr>, and
C<stdout> and C<stderr> will get populated with the I<new> STDOUT and STDERR
from the provided C<$command>.

=over

=item C<stdout> - The STDOUT from the operation. Will be set to the empty string
if undef.

=item C<stderr> - The STDERR from the operation. Will be set to the empty string
if undef.

=item C<exitcode> - The C<$?> equivalent as produced by IO::Async::Process.

=item C<past_stdout> - The STDOUT from the prior command

=item C<past_stderr> - The STDERR from the prior command

=back

C<past_stdout> and C<past_stderr> are never used; they are provided for you to
write any procedure you may require to concatenate new output with old. See
C<gather>.

=cut

sub run {
    my ($self, $command, %data) = @_;
    my $future = loop->new_future;

    $data{stdout} //= '';

    if (ref $command eq 'CODE') {
        loop->run_child(
            code => sub {
                $command->($self, %data); 0;
            },
            setup => [
                chdir => $self->config->{dir}
            ],
            on_finish => sub {
                my (undef, $exitcode, $stdout, $stderr) = @_;
                $future->done(
                    stdout => $stdout, 
                    stderr => $stderr, 
                    exitcode => $exitcode, 
                    past_stdout => $data{stdout},
                    past_stderr => $data{stderr}
                );
            }
        );
    }
    else {
        loop->run_child(
            command => $command,
            setup => [
                chdir => $self->config->{dir}
            ],
            stdin => $data{stdout},
            on_finish => sub {
                my (undef, $exitcode, $stdout, $stderr) = @_;
                $future->done(
                    stdout => $stdout, 
                    stderr => $stderr, 
                    exitcode => $exitcode,
                    past_stdout => $data{stdout},
                    past_stderr => $data{stderr},
                );
            }
        )
    }
    return $future;
}

=head2 gather(%data)

Intended for currying. This goes between C<run>s and ensures output is not lost.

Concatenates the STDOUT and STDERR from the command with the respective STDOUT
or STDERR of the previous command and continues the chain.

    $repo->run([qw/git command/])
        ->then($repo->curry::run([qw/another git command/]))
        ->then($repo->curry::gather)
        ->then(App::Multigit::report($repo))

See C<run> for the shape of the data

=cut

sub gather {
    my ($self, %data) = @_;

    no warnings 'uninitialized';
    my $stdout = join "\n", grep { $_ } delete $data{past_stdout}, $data{stdout};
    my $stderr = join "\n", grep { $_ } delete $data{past_stderr}, $data{stderr};
    $data{stdout} = $stdout;
    $data{stderr} = $stderr;

    Future->done(%data);
}

=head2 report(%data)

Intended for currying, and accepts a hash-shaped list à la C<run>.

Returns a Future that yields a two-element list of the directory - from the
config - and the STDOUT from the command, indented with tabs.

Use C<gather> to collect STDOUT/STDERR from previous commands too.

The yielded list is intended for use as a hash constructor.


    my $future = App::Multigit::each(sub {
        my $repo = shift;
        $repo->run([qw/git command/])
            ->then($repo->curry::run([qw/another git command/]))
            ->then($repo->curry::gather)
            ->then($repo->curry::report)
        ;
    });

    my %report = $future->get;

    for my $dir (sort keys %report) { ... }

=cut

sub report {
    my $self = shift;
    my %data = @_;

    my $dir = $self->config->{dir};

    my $output = do { 
        no warnings 'uninitialized';
        _indent($data{stdout}, 1) . _indent($data{stderr}, 1);
    };

    return Future->done(
        $dir => $output
    );
}


=head2 _indent

Returns a copy of the first argument indented by the number of tabs in the
second argument. Not really a method on this class but it's here if you want it.

=cut

sub _indent {
    return if not defined $_[0];
    $_[0] =~ s/^/"\t" x $_[1]/germ
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
