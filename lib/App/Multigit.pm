package App::Multigit;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Path::Class;
use Config::Any;

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

    return +{
        map { %$_ } values %{$cfg->[0]}
    };
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

