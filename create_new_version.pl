#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Cwd;
use JSON;
use File::Basename;

#Compute the diff between the last stable version and previous versions.
#Stables versions are expected to be tagged with a "stable-XXX" tag (XXX = yearmonthday)
#The new version of the files are stored with filenames xxx.ext.last
#The old version of the files are stored with filenames xxx.ext.orig

my $path_to_hg = '../envadrouille';
my $current_path = getcwd;
chdir($path_to_hg) or die("Directory $path_to_hg does not exist\n");

#Create a new stable branch
my ($sec, $min, $h, $day, $month, $year, @tmp) = localtime();
my $newrev = sprintf("%02d%02d%02d", $year % 100, $month+1, $day);
open(F, "$path_to_hg/admin/index.php");
my @indlines = <F>;
close(F);
open(F, "> $path_to_hg/admin/index.php");
for my $l (@indlines) {
   if($l =~ /^\$VERSION/) {
      $l = "\$VERSION = '$newrev';\n";
   }
   print F $l;
}
close(F);
print "(cd $path_to_hg && hg update default && hg tag stable-$newrev)\n";
print `(cd $path_to_hg && hg update default && hg commit -m 'New revision' && hg tag stable-$newrev)\n`;

#Get list of stable revs
my %tagsrev;
my @tags = reverse sort map {
      if($_ =~ m/(stable-\d+)\s*(\d+):(\w+)/) {
         my $rev = $1;
         $tagsrev{$rev} = $2;
         $rev =~ m/(\d+)/;
         if($1 < 130219) {
            ();
         } else {
            $rev;
         }
      } else {
         ();
      }
   } split(/\n/, `hg tags`);
print Dumper(\@tags);

#Create diffs for each rev
#A diff =
for my $revn (1..$#tags) {
   chdir($current_path);

   print "(cd $path_to_hg && hg update $tags[$revn])\n";
   print `(cd $path_to_hg && hg update $tags[$revn])`;

   #Get list of changed files. Ignores hidden files (.xxx)
   my @diff = map {
    /^diff -r \w+ ([^\.].*)$/ ? { "file" => $1 } : ()
   } split(/\n/, `(cd $path_to_hg && hg diff -r $tagsrev{$tags[0]})`);


   my $patch_dir = "./envadrouille";
   for my $ff (@diff) {
      my $f = $ff->{file};

      my $cmd = "mkdir -p $patch_dir/".dirname($f);
      print `$cmd`;
      print `cat $path_to_hg/$f > $patch_dir/$f.orig`;
      #We must 'cd' to the path otherwise if the current path is also an hg rep, hg gets confused
      print `(cd $path_to_hg && hg cat -r $tagsrev{$tags[0]} $f) > $patch_dir/$f.last`; 
      $ff->{binary} = is_binary("$patch_dir/$f.last");
   }

   open(F, "> diff.json");
   print F to_json(\@diff);
   close(F);

   print `zip -r patch-$tags[$revn]-$tags[0].zip diff.json $patch_dir`;
   print `rm -rf diff.json $patch_dir`;

   print "(cd $path_to_hg && hg update && hg log --style changelog -P $tags[$revn] -b default -X .hgtags) | tail -n +2 > CHANGELOG-$tags[$revn]-$tags[0]\n";
   print `(cd $path_to_hg && hg update && hg log --style changelog -P $tags[$revn] -b default -X .hgtags) | tail -n +2 > CHANGELOG-$tags[$revn]-$tags[0]`;
   my $changes = `cat CHANGELOG-$tags[$revn]-$tags[0]`;
   open(F, "> CHANGELOG-$tags[$revn]-$tags[0]");
   print F 'showChangelog('.to_json({'changelog' => $changes}).')';
   close(F);
}

print "(cd $path_to_hg && hg update && hg archive $current_path/latest.zip)\n";
print `(cd $path_to_hg && hg update && hg archive $current_path/latest.zip)`;

open(F, "> VERSION");
my ($revdate) = ($tags[0] =~ m/stable-(\d+)/);
print F "remote_check_version({\"version\":$revdate})";
close(F);


sub is_binary {
   my ($f) = @_;
   my $meta = `file $f`;
   if($meta =~ /text/) {
      return 0;
   } else {
      return 1;
   }
}
