package App::Multigit;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Path::Class;
use Config::Any;

=head1 NAME

App::Multigit - The great new App::Multigit!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

sub mgconfig() {
    return '.mgconfig';
}

sub mg_parent {
    my $pwd = shift // dir->absolute;

    do {
        return $pwd if -e $pwd->file(mgconfig);
        last if $pwd eq $pwd->parent;
    }
    while ($pwd = $pwd->parent);

    die "Could not find .mgconfig in any parent directory";
}

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

=head1 AUTHOR

Alastair McGowan-Douglas, C<< <altreus at perl.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-multigit at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Multigit>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Multigit


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Multigit>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Multigit>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Multigit>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Multigit/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Alastair McGowan-Douglas.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of App::Multigit
