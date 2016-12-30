use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Statistics::Sampler::Multinomial',
    AUTHOR              => 'Shawn Laffan <shawnlaffan@gmail.com>',
    VERSION_FROM        => 'lib/Statistics/Sampler/Multinomial.pm',
    ABSTRACT_FROM       => 'lib/Statistics/Sampler/Multinomial.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Statistics-Sampler-Multinomial-*' },
);
