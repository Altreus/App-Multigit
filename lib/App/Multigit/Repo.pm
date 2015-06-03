package App::Multigit::Repo;

use App::Multigit::Loop qw(loop);
use IO::Async::Process;
use Moo;
use Cwd 'getcwd';

use 5.014;

has name => (
    is => 'ro',
);

has config => (
    is => 'ro',
);

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
