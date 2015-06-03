package App::Multigit::Loop;

use strict;
use warnings;
use IO::Async::Loop;
use 5.014;

use base qw(Exporter);

our @EXPORT_OK = qw(loop);

sub loop {
    state $loop = IO::Async::Loop->new;
    $loop;
}

1;
