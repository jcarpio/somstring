#!/usr/bin/perl

# PROGRAM  : somstring_v??.pl
# PURPOSE  : Execute examples of SOMString
# AUTHOR   : Jose Carpio Cañada jose.carpio@dti.uhu.es 
# CREATED  : Tue Marzo 5 2008
# REVISION : $Id: fasta_read.pl,v 0.0 2008/03/05 09:14:51 bosborne Exp $
#
# INSTALLATION
#    If you have installed biopel using the standard
#    makefile system everything should be fine and 
#    dandy.
#
#    if not edit the use lib "...." line to point the directory
#    containing your Bioperl modules.
#

# new sequence from raw memory...
# it is *very* important to get the type right so it
# is translated correctly.

   BEGIN { push @INC, "/home/jcarpio/som_string/share/perl/5.14.2/"}

   use warnings;
   use strict;
   use AI::NeuralNet::SOMString;
   use Tree::Ternary_XS;
   # use Bio::Seq;
   # use Bio::SeqIO;


   my $version = "0.21";

   # Create a new self-organizing map.
   my $som = AI::NeuralNet::SOMString->new();
   my $xdim = shift || 5; # X Dimension of map 
   my $ydim = shift || 5; # Y Dimension of map
   my $idim = 1; # Dimension of input data
   my $topology = 'hexa'; # Map topolgy 
   my $neighborhood = 'bubble'; # neighborhood function type
   my $epoch = shift || 0;
   my $alpha = shift || 0.7;
   my $radius = shift || 3;
   my $alpha_type = shift || 'linear';    
   my $input_type = shift || 'file';
   my $tree = new Tree::Ternary_XS;

   # Open fist argument or test.seq
   my $file = shift || "test.seq";
   my @data;
   my @data_ini = ("0000000", "0000000", "0000000"); 
   my $initial_map_file = shift || "";
   my $qerr;
   my $input_lines = 0;
   my %seq_array;
   my @arrays_of_bests;
   my $max_length=0;
   my $seqin; 
   my $seqout;

   if ($input_type eq 'file') {
      open(FILE, "<$file");

      while (<FILE>) {
         my $str = $_;
         if(length($str)> $max_length) {
            $max_length = length($str);
         }

         if ($str=~ /(.*)\n$/) {
            $str = $1;
         }

        push @data, $str;
        $tree->insert($str);
         my $label = $str; 
         $seq_array{$str} = $label;

         $input_lines++;
      }
   } else { # fasta
      $seqin  = Bio::SeqIO->new(-file => $file , '-format' => 'Fasta');
      $seqout = Bio::SeqIO->new('-format' => 'fasta', -fh => \*STDOUT);

      while ( my $seq = $seqin->next_seq() ) {
         my $seq_str = $seq-> seq();
         if(length($seq_str)> $max_length) {
           $max_length = length($seq_str);
         }
         my $seq_id = $seq-> id;
         #if ($seq_id =~ /HUMAN/) {
            push @data, $seq_str;
            #if($input_lines < 50001) {     
               $tree->insert($seq_str);
               # $seq_id =~ /(\w*)\|.*/;
               # $seq_id =~ /(\w*)\..*/;

               $seq_id =~ /(.*)/;
               my $label = $1; 
               $seq_array{$seq_str} = $label;
               $input_lines++;
            #}   
         #} 
      }
   }

   print "Input lines = $input_lines\n";

   print "-----------------------------------------------------\n";
   print "Epochs = $epoch\n";
   # Initialize map.
                     
   my $file_map_name_previous = "umat_". ($epoch-5) . "_epoch" . "_" . $xdim . "x" . $ydim . "_" . $input_lines . "_str_" . $alpha . "_alpha_" . $alpha . "alpha_" . $alpha_type . "_alpha_type_" . $radius . "_radius_". $input_type . "_input_type_". $version. "_ver.map";
   if (-e "$file_map_name_previous")  {                
      printf "Reutilizando fichero anterior $file_map_name_previous\n";
      # JCC this initilization is only to calculate the difference between 
      # initializing error and after training error             
      # $som->initialize($xdim, $ydim, $idim, $topology, $neighborhood,'random',111223,\@data);
      # $qerr = $som->qerror(\@data);q
      # print "Mean quantization error before trainig= $qerr\n"; 
      print "Initializing \'$file_map_name_previous'...\n";
      open(FILE_PREVIOUS, "<$file_map_name_previous");
      $som->load(*FILE_PREVIOUS);
      print "#############################################################\n";       
      print "# Initial map                                               #\n";
      $som-> print_map();
      $som->train(5, $alpha, $radius, $alpha_type, \@data);
   } else { 
      $file_map_name_previous = "umat_". ($epoch-50) . "_epoch" . "_" . $xdim . "x" . $ydim . "_" . $input_lines . "_str_" . $alpha . "_alpha_" . $alpha . "alpha_" . $alpha_type . "_alpha_type_" . $radius . "_radius_". $input_type . "_input_type_" . $version. "_ver.map";
      if (-e "$file_map_name_previous") {
         printf "Reutilizando fichero anterior $file_map_name_previous\n";
         # JCC this initilization is only to calculate the difference between 
         # initializing error and after training error             
         # $som->initialize($xdim, $ydim, $idim, $topology, $neighborhood,'random',111223,\@data);
         # $qerr = $som->qerror(\@data);
   	 # print "Mean quantization error before trainig= $qerr\n";
         print "Initializing \'$file_map_name_previous'...\n";
         open(FILE_PREVIOUS, "<$file_map_name_previous");
         $som->load(*FILE_PREVIOUS);
         print "#############################################################\n";       
         print "# Initial map                                               #\n";
         $som-> print_map();
         $som->train(50, $alpha, $radius, $alpha_type, \@data);
      } else {
         if(-e "$initial_map_file") {
            print "Initializing \'$initial_map_file'...\n";                  
            open(FILE_INITIAL, "<$initial_map_file");
            $som->load(*FILE_INITIAL);
         } else {
            print "Initializing randomly...\n";         
            $som->initialize($xdim, $ydim, $idim, $topology, $neighborhood,'random',111223,\@data_ini);
         }
         # $qerr = $som->qerror(\@data);
   	 # print "Mean quantization error before trainig= $qerr\n";
         print "Training ...\n";
         if($epoch != 0) {
            print "#############################################################\n";       
            print "# Initial map                                               #\n";
            $som-> print_map();
            $som->train($epoch, $alpha, $radius, $alpha_type, \@data);
         }
      }
   }
   # $qerr = $som->qerror(\@data);
   # print "Mean quantization error after trainig= $qerr\n\n";

   # JCC 
   # Calibrating the map
   # I need a map with real values
   # Umatrix and SOMString result have not real values
   # each node have an evolution of input values.
   # we need to find for each node, which value of input set
   # are nearest.

   # algorithm
   # for all nodes n in map do
   #   find nearest in imput data
   #   this is the label for this node  
   # end do

   print "Calibrating...\n";

   # my @datos = ('ACGT'); 
   # my ($xwin, $ywin, $min_diff) = $som->winner(\@datos);
  
   # Calibrating method that take each element from input
   # data set and them select the best pattern in map

   for my $k (0 .. $som->{XDIM}*$som->{YDIM}-1) {
      my @tmp_array = ();
      $arrays_of_bests[$k] = \@tmp_array; 
   }

   for (my $i=0; $i < @data; $i++) {
     my @tmp_array = ($data[$i]);
     my ($xwin, $ywin, $min_diff) = $som->winner(\@tmp_array);
     # print "xwin= $xwin ywin=$ywin min_diff= $min_diff\n";   
     my $best_array = $arrays_of_bests[($ywin * $som->{XDIM} + $xwin) * $som->{IDIM}];   
     push @$best_array, $data[$i] ;
     $arrays_of_bests[($ywin * $som->{XDIM} + $xwin) * $som->{IDIM}] = $best_array;         
   }

   # Calibrating method that take each pattern in map and select 
   # best element from input data set
   # for my $y (0..$som->{YDIM}-1) {
   #   for my $x (0..$som->{XDIM}-1) {
   #      my $node_value = $som->{MAP}->[($y * $som->{XDIM} + $x) * $som->{IDIM}];
   #      my ($best, $array_best);
   #      ($best, $array_best) = $som-> best_in_tree($tree, $node_value, $max_length);    
   #      $som->{MAP}->[($y * $som->{XDIM} + $x) * $som->{IDIM}] = $best;
   #      $arrays_of_bests[($y * $som->{XDIM} + $x) * $som->{IDIM}] = 	$array_best;
   #      print ".";
   #   }
   #   print ".";
   # }
   print "\n";
  
   # $qerr = $som->qerror(\@data);
   # print "Mean quantization error after calibration= $qerr\n";
        
   # Writing map file
   print "Writing map file ...\n";
   my $file_map_name = "umat_". $epoch . "_epoch" . "_" . $xdim . "x" . $ydim . "_" . $input_lines . "_str_" . $alpha . "_alpha_" . $alpha_type . "_alpha_type_" . $radius . "_radius_". $input_type . "_input_type_" . $version. "_ver.map";
   open(FILE_OUT, ">$file_map_name");
   $som->save(*FILE_OUT);

   # Writing umatrix
   print "Writing umatrix file ...\n";
   my $file_umat_name = "umat_". $epoch . "_epoch" . "_" . $xdim . "x" . $ydim . "_" . $input_lines . "_str_" . $alpha . "_alpha_" . $alpha_type . "_alpha_type_". $radius . "_radius_". $input_type . "_input_type_" . $version. "_ver.umat";
   open(FILE_UMAT, ">$file_umat_name");
   $som ->header_to_file(*FILE_UMAT);
   my ($i, $j, $k);
   $k = 0;              
   my $umat = $som->umatrix;
   for $j (0..$som->y_dim*2-2) {
      for $i (0..$som->x_dim*2-2) {
         my $id = "";
         if($k < ($som->{XDIM}*$som->{YDIM}) ) { # label the map not the umatrix
            # $k take elements between 0 and XDIM*YDIM-1 

            while(@{$arrays_of_bests[$k]}) { # take labels from all best inputs                                                         
               my $tmp = shift @{$arrays_of_bests[$k]}; # take first XDIM*YDIM matrix (map)
               if($tmp) { 
                  $id = $id . $seq_array{$tmp} . ":";
               }
            }
            chop $id;  # cut last "-"                      
            print FILE_UMAT "$umat->[$j*($som->x_dim*2-1)+$i] $id\n";
         } else { # no label
	    print FILE_UMAT "$umat->[$j*($som->x_dim*2-1)+$i]\n";
         }
         $k++;
      }
   }

   # my @datos = ('ACGT'); 
   # my ($xwin, $ywin, $min_diff) = $som->winner(\@datos);
   # 
   # print "And the winner is ... \n";
   # print "xwin = $xwin\n";
   # print "ywin = $ywin\n";	
   # print "min_diff = $min_diff\n";
   print "Writing ps file ...\n";
   my $file_ps_name = "umat_". $epoch . "_epoch" . "_" . $xdim . "x" . $ydim . "_" . $input_lines . "_str_" . $alpha . "_alpha_" . $alpha_type . "_alpha_type_". $radius . "_radius_". $input_type . "_input_type_" . $version. "_ver.ps";

   my $pwd = `/bin/pwd`;
   chomp $pwd;
               
   $file_ps_name = $pwd . "/" .$file_ps_name;

   `/home/jose/Escritorio/investigacion/som_pak/mio/umat -cin $file_umat_name -fontsize 0.3 > $file_ps_name`;
   close(FILE_OUT);
   close(FILE_UMAT);
   close(FILE_PREVIOUS);
