#!/bin/bash

# Update all PHP interfaces to RABX.

# Includes some extra stuff specific to some of thet types.  TODO remove need
# for this by removing need for include files, and handling error codes better.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: rabxtophp-all.sh,v 1.4 2005-09-14 18:05:46 francis Exp $

echo "EvEl..."
./rabxtophp.pl ../services/EvEl/perllib/EvEl.pm > ../phplib/evel.php

echo "DaDem..."
cat <<END >../phplib/dadem.php
<?
# this part from rabxtophp-all.sh 

require_once('utility.php');
require_once('votingarea.php');

/* Error codes */
define('DADEM_UNKNOWN_AREA', 3001);        /* unknown area */
define('DADEM_REP_NOT_FOUND', 3002);       /* unknown representative id */
define('DADEM_AREA_WITHOUT_REPS', 3003);   /* not an area for which representatives are returned */

define('DADEM_CONTACT_FAX', 101);
define('DADEM_CONTACT_EMAIL', 102);
?>
END
./rabxtophp.pl ../services/DaDem/DaDem.pm >>../phplib/dadem.php

echo "MaPit..."
cat <<END >../phplib/mapit.php
<?
# this part from rabxtophp-all.sh 

require_once('votingarea.php');

/* Error codes */
define('MAPIT_BAD_POSTCODE', 2001);        /* not in the format of a postcode */
define('MAPIT_POSTCODE_NOT_FOUND', 2002);  /* postcode not found */
define('MAPIT_AREA_NOT_FOUND', 2003);      /* not a valid voting area id */
?>
END
./rabxtophp.pl ../services/MaPit/MaPit.pm >>../phplib/mapit.php

echo "Gaze..."
./rabxtophp.pl ../services/Gaze/perllib/Gaze.pm >../phplib/gaze.php

