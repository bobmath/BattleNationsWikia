BattleNationsWikia
==================

Wikitext builder for the game BattleNations.

Written in Perl.

The main script, readbn, finds the latest game files and processes
them into wikitext suitable for battlenations.wikia.com.

Installation
------------

If you are not a Perl Master, I recommend using MacPorts
(http://www.macports.org/install.php). After doing the base install,
you will need to run this command to get the dependencies:

   sudo port install perl5 p5-data-dump p5-dbi p5-dbd-sqlite p5-digest-sha1 p5-file-homedir p5-json-xs

If you are on Linux or Windows, you can probably find packages with
the required modules somewhere.

