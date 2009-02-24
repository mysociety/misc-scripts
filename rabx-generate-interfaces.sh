#!/bin/bash

# rabx-generate-interfaces:
# Update all PHP and Perl interfaces to RABX. Syntax check the newly created
# PHP files.

# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: rabx-generate-interfaces.sh,v 1.5 2009-02-24 14:49:40 francis Exp $

echo "EvEl..."
./rabxtopl.pl ../services/EvEl/perllib/EvEl.pm "" > ../perllib/mySociety/EvEl.pm
./rabxtophp.pl ../services/EvEl/perllib/EvEl.pm "" > ../phplib/evel.php
php -l ../phplib/evel.php
echo "DaDem..."
./rabxtopl.pl ../services/DaDem/DaDem.pm "" >../perllib/mySociety/DaDem.pm
./rabxtophp.pl ../services/DaDem/DaDem.pm "" >../phplib/dadem.php
php -l ../phplib/dadem.php
echo "MaPit..."
./rabxtopl.pl ../services/MaPit/MaPit.pm "" >../perllib/mySociety/MaPit.pm
./rabxtophp.pl ../services/MaPit/MaPit.pm "" >../phplib/mapit.php
./rabxresttopy.pl ../services/MaPit/MaPit.pm "" >../pylib/mysociety/mapit.py
php -l ../phplib/mapit.php
echo "Gaze..."
./rabxtopl.pl ../services/Gaze/perllib/Gaze.pm "" >../perllib/mySociety/Gaze.pm
./rabxtophp.pl ../services/Gaze/perllib/Gaze.pm "" >../phplib/gaze.php
php -l ../phplib/gaze.php
echo "FYR Queue..."
./rabxtophp.pl ../fyr/perllib/FYR/Queue.pm "../../phplib/" >../fyr/phplib/queue.php
php -l ../fyr/phplib/queue.php
echo "NeWs..."
./rabxtopl.pl ../services/NeWs/perllib/NeWs.pm "" > ../perllib/mySociety/NeWs.pm
./rabxtophp.pl ../services/NeWs/perllib/NeWs.pm "" > ../phplib/news.php
php -l ../phplib/news.php
