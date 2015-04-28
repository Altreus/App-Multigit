use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::Multigit',
    AUTHOR           => q{Alastair McGowan-Douglas <altreus@perl.org>},
    VERSION_FROM     => 'lib/App/Multigit.pm',
    ABSTRACT_FROM    => 'lib/App/Multigit.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Future' => 0.30,
        'IO::Async' => 0.64,
        'Path::Class' => 0.35,
        'File::Which' => 1.09,
        'Opt::Imistic' => 0.04,
        'Capture::Tiny' => 0.25,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'App-Multigit-*' },
);
