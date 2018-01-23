#!/usr/bin/perl	

# $Id: SOMString.pm, v0.06 2008/03/06
#
# Modify by Jose Carpio, University of Huelva, the SOM.pm package implemented 
# by Alexander Voischev, Russian Federation to compute directly input strings values 
#
# See AUTHOR section in pod text below for usage and distribution rights.   
#
# 

BEGIN {
	$AI::NeuralNet::SOMString::VERSION = "0.06";
}

package AI::NeuralNet::SOMString;

require 5.005_62;
use strict;
use warnings;
use Carp;
use POSIX;
use locale;

require Exporter;
use AutoLoader qw(AUTOLOAD);

use Tree::Ternary_XS; # to fast string search in best_in_data_set method
use String::Diff; # to use in method new_string
use String::Diff qw(diff_merge); # export functions

use Text::LevenshteinXS qw(distance);

our @ISA = qw(Exporter);

our $VERSION = '0.06';

$AI::NeuralNet::SOMString::INV_ALPHA_CONSTANT  = 100.0;

#####################################################
#
# "Public" methods.
#
#####################################################

	##################################################
	#
	#
	#
	##################################################
	sub new {
		my $class = shift;
		my $self = {};
		bless($self, $class);
		$self->{XDIM} = 0;
		$self->{YDIM} = 0;
		$self->{IDIM} = 0;
		$self->{MAP} = ();
		$self->clear_all_labels;
		return $self;
	}

        
        ##################################################
	#
	#
	#
	##################################################
        # JCC
	sub print_map {
          my $self = shift;
          my $array = $self->{MAP};

          for my $i (0..@$array-1) { 
            print "$self->{MAP}->[$i]\t";
            if(($i+1) % $self->{XDIM} == 0) {
               print "\n";
            }           
          } 
          print "#############################################################\n";       
        }


        ##################################################
	#
	#
	#
	##################################################
        # JCC
        # new version 0.16
	sub new_string_diff {
           my $distance = shift;
           my $str1     = shift;
           my $str2     = shift;
           my $todo     = shift;
           my $todo_org = $todo;
           my $todo_prev = "";
            
           if($distance == 0) {
              return $str1;          
           }

           my $operator = "";
           my $element = "";
           my $new_string = "";
           my $i = 0;
           my $firsts = "";
           my $rest   = $str1;
           my $prefix = "";
           

         
           #  ^   Match the beginning of the line
           # [^<] all except "<"
           #                     1      2       3             4
           while ( ($todo =~ /(^[^<]*)<([^>]*)>([^<])<\/[^>]*>(.*)/) && ($i < $distance) ) { 
              $prefix = $1;              
              $operator = $2;
              $element = $3;
              $todo_prev = $todo;
              $todo = $4;
              # $1 = first part of string
              # $2 = del or ins
              # $3 = element to insert or delete
              # $4 = rest of things to do 

              #--- debug -------------------
              # if ($prefix =~ />/) {
              #    print "prefix = $prefix\n";
              # }
              #-----------------------------  
       
              $new_string .= $1;
              
              $rest =~ /^$prefix(.*)/; # deleted first part
              $rest = $1;
                            
              if($operator eq "ins") {
                $new_string .= $element; 
                $i ++;
              }
              if ($operator eq "del") {
                $rest =~ /^.(.*)/; # deleted the first element
                $rest = $1;
                $i++;
              }    
           }
           $new_string .= $rest; # included the rest to new_string
           return $new_string;
        }
        ##################################################
	#
	#
	#
	##################################################
        # JCC
	sub distance_diff {
           my $self = shift;
           my $diff = shift;  
           my $distance = 0;
           my $tmp = $diff;
           my $string = "";

           #                 1       2       3             4
           while($tmp =~/^([^<]*)<([^>]*)>([^<])<\/[^>]*>(.*)/) {
             # $1 initial part of string
             # $2 del or ins
             # $3 element to delete or insert
             # $4 rest of string
             $tmp = $4;
            
             $string .= $1 . "<" . $2 . ">" . $3 . "</" . $2 . ">";
             $distance++;
           }

           return $distance;
        }


        ##################################################
	#
	#
	#
	##################################################
        # JCC

	sub slow_diff {
           my $self = shift;
           my $str1 = shift;  
           my $str2 = shift;
           my $tmp = "";
           my $string = "";

           my $diff = String::Diff::diff_merge($str1, $str2,
              remove_open => "<del>",
              remove_close => "</del>",
              append_open => "<ins>",
              append_close => "</ins>",
           );
            
           $tmp = $diff;
           #                 1       2       3     4              5      
           while($tmp =~/^([^<]*)<([^>]*)>([^<])([^<]*)<\/[^>]*>(.*)/) {
             # $1 initial part of string
             # $2 del or ins
             # $3 element to delete or insert
             # $4 rest of string
             if($4) { # $4 != "" more than one element inside <del|ins> </del|ins>
               $tmp = "<" . $2 . ">" . $4 . "</". $2 . ">".  $5; 
             } else { # only one element inside <del|ins> </del|ins>
               $tmp = $5;
             }
             $string .= $1 . "<" . $2 . ">" . $3 . "</" . $2 . ">";
           }
           return $string;
        }

	##################################################
	#
	#
	#
	##################################################
        sub _div {
          my $a = shift;
          my $b = shift;

          # a div b = (a - (a % b) / b );
          return (($a - ($a % $b)) / $b);
        }

	##################################################
	#
	#
	#
	##################################################
        sub best_in_tree {
          my $self = shift;
          my $tree = shift;            
          my $node_value = shift;
          my $max_length = shift;
          my $max_distance = $max_length * 2;

          my @list;
         
          # a div b = (a - (a % b) / b );

          #my $distance = _div($max_length-length($node_value), 2);
          #my $continue = 1;

          #while ($continue) {
          #   # @list = $tree->nearsearch($distance, $node_value);         
          #   @list = $tree->nearsearch(540, "ACGT");         
          #   if ($list[0]) {
          #      # first half
          #      $distance = $distance - $distance/2;                
          #   } else {            
          #      # second half
          #      $distance = $distance + $distance/2;
          #      if($distance <5) {
          #         $continue = 0;
          #      }
          #   }
          #}

          for my $i (0 .. $max_distance) {              
             @list = $tree->nearsearch($i, $node_value);         
             if ($list[0]) {
               return ($list[0], \@list);
             }
          }         
        }


	##################################################
	#
	#
	#
	##################################################
        sub best_in_data_set {
          my $self = shift;
          my $data = shift;
          my $node_value = shift;
          my $min_distance = 999999999999;
          my $distance;
          my $min_input;
          my $dif = "";
          my @result;

          # croak "Invalid Data parameter" if ((ref($data) eq 'ARRAY') and (@$data % $self->{IDIM}));

          my $patterns_count = @$data;

          for my $p (0..$patterns_count-1) {
             # JCC modified to calculate the distance faster
             # $dif = $self-> slow_diff(@$data[$p], $node_value);
             # $distance = $self-> distance_diff($dif);
             $distance = distance(@$data[$p], $node_value);
             if ($distance < $min_distance) {
              $min_distance = $distance;
              $min_input    = @$data[$p];            
              @result = (@$data[$p]);  
            } else{
              if ($distance == $min_distance) {
                push @result, @$data[$p];                
              }
            }
            $dif = "";
          }
          return ($min_input, \@result);
        }

	##################################################
	#
	#
	#
	##################################################
	sub initialize {
	   my $self = shift;
		my $xdim = shift; # X Dimension of map
		my $ydim = shift; # Y Dimension of map
		my $idim = shift; # Dimension of input data
		my $topology = shift; # Map topolgy
		my $neighborhood = shift; # neighborhood function type
		my $init_type = shift; # Initialization type
		my $random_seed = shift; # Random seed
		my $data = shift; # Data values for initialize

		# Checking error in arguments
		croak "Invalid XDim parameter" if ($xdim < 1);
		croak "Invalid YDim parameter" if ($ydim < 1);
		croak "Invalid IDim parameter" if ($idim != 1);
		croak "Invalid topology parameter" if ($topology ne 'hexa') and ($topology ne 'rect');
		croak "Invalid neighborhood parameter" if ($neighborhood ne 'bubble') and ($neighborhood ne 'gaussian');
		croak "Invalid initialization type parameter" if ($init_type ne 'random');
		croak "Invalid Random seed parameter" if ($random_seed < 0);
		croak "Invalid Data parameter" if ((ref($data) eq 'ARRAY') and (@$data % $idim));

		$self->{XDIM} = $xdim;
		$self->{YDIM} = $ydim;
		$self->{IDIM} = 1; # JCC input dimension for string input data is 1. Keep for compatibility only
		$self->{TOPOLOGY} = $topology;
		$self->{NEIGHBORHOOD} = $neighborhood;
		$self->{RANDOMSEED} = $random_seed;

		my $patterns_count = @$data / $idim;

		srand($random_seed);
					
                # JCC modified to accept only string data input
                # The initilize process take randomly values from 
                # input data
                my $c = 0;
                if ($init_type eq 'random') {
                  for my $z (0..$xdim * $ydim-1) {
                    for my $i (0..$idim-1) {
                      my $random = _round(rand $patterns_count-1);
                      # return a number between 0 and $patterns_count -1 
                      $self->{MAP}->[$c++] = $data->[$random];
                    }
                  }
		}
		
	}
   


	##################################################
	#
	#
	#
	##################################################
	sub train {
		my $self = shift;
		my ($train_length, $alpha, $radius, $alpha_type, $data) = @_;
                my $max_diff=0;
                my $modified = 0;

	  	croak "Invalid Data parameter" if ((ref($data) eq 'ARRAY') and (@$data % $self->{IDIM}));

		my ($adapt_func, $alpha_func);
		if ($self->{NEIGHBORHOOD} eq 'bubble') {
			$adapt_func = '_adapt_bubble';
		}
		else {
			$adapt_func = '_adapt_gaussian';
		}

		if ($alpha_type eq 'linear') {
			$alpha_func = '_alpha_linear';
		}
		else {
			$alpha_func = '_alpha_inverse_t';
		}

		my $p = 0;
		my $patterns_count = @$data / $self->{IDIM};
		my ($trad, $talp);
		my ($xwin, $ywin, $min_diff);

		my @data_slice;
		for my $len (0..$train_length-1) {

			if (++$p == $patterns_count) {$p = 0;}

			$trad = 1.0 + ($radius - 1.0) * ($train_length - $len) / $train_length;
			$talp = $self->$alpha_func($len, $train_length, $alpha);
                        # Debug JCC 
                        print "#############################################################\n";       
                        print "epoch= $len   radius = $trad   alpha= $talp\n";

			@data_slice = @$data[$p*$self->{IDIM}..($p+1)*$self->{IDIM}-1];
                        # JCC working with a slice of data
			($xwin, $ywin, $min_diff) = $self->winner(\@data_slice);                        
			$modified = $self->$adapt_func($xwin, $ywin, $trad, $talp, \@data_slice); 
                        if ($modified == 0) {
                           print "Map not modified at $len epoch\n";   
                           return;
                        }
                        # Debug JCC
                        # print map for each epoch
                        $self->print_map();
		}
	}

	##################################################
	#
	#
	#
	##################################################
	sub qerror {
		my $self = shift;
		my $data = shift;

	  	croak "Invalid Data parameter" if ((ref($data) eq 'ARRAY') and (@$data % $self->{IDIM}));

		my $patterns_count = @$data / $self->{IDIM};
		my ($xwin, $ywin, $min_diff);
		my $qerror=0;

		my @data_slice;
		for my $p (0..$patterns_count-1) {
			@data_slice = @$data[$p*$self->{IDIM}..($p+1)*$self->{IDIM}-1];
                        #JCC I have to modify "winner" function
			($xwin, $ywin, $min_diff) = $self->winner(\@data_slice);

			$qerror += $min_diff;
		}
		return ($qerror/$patterns_count);
	}

	##################################################
	#
	#
	#
	##################################################
	sub winner {
		my $self = shift;
		my $data = shift;

		my ($xwin, $ywin); 
		my ($diff, $difference, $masked);
		my $min_diff = DBL_MAX;
                my @array_winners = ("0-0-$min_diff");

		for my $y (0..$self->{YDIM}-1) {
			for my $x (0..$self->{XDIM}-1) {
				$masked = 0;
				$difference = 0.0;
				for my $i (0..$self->{IDIM}-1) {
				  # JCC modified to check strings
                                  my $string_map  = $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i];
                                  my $string_data =  $data->[$i];
                                  #JCC changed to make faster distance                                           
                                  my $dif = $self-> slow_diff($string_map, $string_data);
                                  $diff = $self-> distance_diff($dif);
                                  # LevenshteinXS distance
                                  # $diff = distance($string_map, $string_data);
				  $difference += $diff ** 2;                                                                   			
				}
				# If data pattern is empty
				croak "Empty pattern" if ($masked == $self->{IDIM});

                                # JCC include the best in a list and take one randomly
                                # TODO                       
                                if ($difference == $min_diff) {
                                   push @array_winners, "$x-$y-$difference";
                                }                               

				# If distance is smaller than previous distances 
				if ($difference < $min_diff) {
					$xwin = $x;
					$ywin = $y;
					$min_diff = $difference;
                                        @array_winners = ();
                                        @array_winners= "$x-$y-$difference";
				}                               
			}
                        
		}                
                if ($#array_winners > 0) {
                  my $random = _round(rand $#array_winners);
                  $array_winners[$random] =~ /(.*)-(.*)-(.*)/;
                  $xwin = $1;
                  $ywin = $2;
                  $min_diff = $3;
                } else {
                  $array_winners[0] =~ /(.*)-(.*)-(.*)/;
                  $xwin = $1;
                  $ywin = $2;
                  $min_diff = $3;
                }                
		return ($xwin, $ywin, sqrt($min_diff));
	}

	##################################################
	#
	#
	#
	##################################################
	sub set_label {
		my $self = shift;
		my ($x, $y, $label) = @_;
		croak "Invalid argument" if (($x<0) or ($x>=$self->{XDIM}) or ($y<0) or ($y>=$self->{YDIM}) or not defined($label));
		$self->{LABELS}->[$y * $self->{XDIM} + $x] =$label;
	}

	##################################################
	#
	#
	#
	##################################################
	sub clear_all_labels {
		my $self = shift;
		$self->{LABELS} = ();
	}

	##################################################
	#
	#
	#
	##################################################
	sub save {
		my $self = shift;
		my $file = shift;

		my $xdim = $self->{XDIM};
		my $ydim = $self->{YDIM};
		my $idim = $self->{IDIM};
		my $topol = $self->{TOPOLOGY};
		my $neigh = $self->{NEIGHBORHOOD};
		print $file "# Created by SOMString.pm v0.01 by Jose Carpio e-mail: jose.carpio\@dti.uhu.es\n";
		print $file "$idim $topol $xdim $ydim $neigh\n";

		for my $z (0..$self->{XDIM}*$self->{YDIM}-1) {
			for my $i (0..$self->{IDIM}-1) {
				my $value = $self->{MAP}->[$z * $self->{IDIM} + $i];
				print $file "$value ";
			}
			my $label = $self->{LABELS}->[$z];
			print $file "$label" if (defined($label));
			print $file "\n";
		}
	}


	sub header {
		my $self = shift;

		my $xdim = $self->{XDIM};
		my $ydim = $self->{YDIM};
		my $idim = $self->{IDIM};
		my $topol = $self->{TOPOLOGY};
		my $neigh = $self->{NEIGHBORHOOD};
		print "# Created by SOMString.pm v0.01 by Jose Carpio e-mail: jose.carpio\@dti.uhu.es\n";
		print "$idim $topol $xdim $ydim $neigh\n";
	}

        # JCC included to save header to argument $file
	sub header_to_file {
		my $self = shift;
		my $file = shift;

		my $xdim = $self->{XDIM};
		my $ydim = $self->{YDIM};
		my $idim = $self->{IDIM};
		my $topol = $self->{TOPOLOGY};
		my $neigh = $self->{NEIGHBORHOOD};
		print $file "# Created by SOMString.pm v0.01 by Jose Carpio e-mail: jose.carpio\@dti.uhu.es\n";
		print $file "$idim $topol $xdim $ydim $neigh\n";
	}


	##################################################
	#
	#
	#
	##################################################
	sub load {
		my $self = shift;
		my $file = shift;
		my $header;

		while (<$file>) {
			if (!/^ *#/) {
				s/^ *//;
				$header = $_;
				last;
			}
		}
		chomp($header);
		my ($idim, $topology, $xdim, $ydim, $neighborhood) = split(/ /, $header);

		croak "Invalid XDim parameter" if ($xdim < 1);
		croak "Invalid YDim parameter" if ($ydim < 1);
		croak "Invalid IDim parameter" if ($idim < 1);
		croak "Invalid topology parameter" if ($topology ne 'hexa') and ($topology ne 'rect');
		croak "Invalid neighborhood parameter" if ($neighborhood ne 'bubble') and ($neighborhood ne 'gaussian');

		$self->{XDIM} = $xdim;
		$self->{YDIM} = $ydim;
		$self->{IDIM} = $idim;
		$self->{TOPOLOGY} = $topology;
		$self->{NEIGHBORHOOD} = $neighborhood;

		my @pattern;
		my @line;
		my @data;
		my $z = 0;
		while (<$file>) {
			if (!/^ *#/) {
				chomp();
				if (/#/) {
				    @line = split(/ /,$`);
				}
				else {
				    @line = split(/ /);
				}
				@pattern = splice(@line, 0, $self->{IDIM});
				push (@data, @pattern);
				if (defined($line[0])) {
					$self->{LABELS}->[$z] = $line[0];
				}
				$z++;
			}
		}
		$self->{MAP} = \@data;
	}

	##################################################
	#
	#
	#
	##################################################
	sub umatrix {
		my $self = shift;
		my ($i,$j,$k,$count,$bx,$by,$bz);
		my ($dx,$dy,$dz1,$dz2,$dz,$temp,$max,$min,$bw);
		my @medtable;
		my $tmp;
                my $distance;

		my @umat = ();

		if ($self->{XDIM}<=0 or $self->{YDIM}<=0 or $self->{IDIM}<=0) {
			return undef;
		}
		$max = 0;
		$min = 0;

		if ($self->{TOPOLOGY} eq 'rect') {
		# Rectangular topology
			for $j (0..$self->{YDIM}-1) {
				for $i (0..$self->{XDIM}-1) {
					$dx=0; $dy=0; $dz1=0; $dz2=0; $count=0;
					$bx=0; $by=0; $bz=0;
					for $k (0..$self->{IDIM}-1) {
						if ($i < $self->{XDIM}-1) {
							# JCC $temp = $self->map($i,$j,$k) - $self->map($i+1,$j,$k);
                                                        #my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i+1,$j,$k)); 
                                                        #$temp = $self-> distance_diff($diff); 
                                                        $temp = distance($self->map($i,$j,$k), $self->map($i+1,$j,$k)); 
							$dx += $temp ** 2;
							$bx = 1;
						}
						if ($j < $self->{YDIM}-1) {
							# JCC $temp = $self->map($i,$j,$k) - $self->map($i,$j+1,$k);
                                                        # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i,$j+1,$k));  
                                                        # $temp = $self-> distance_diff($diff);
                                                        $temp = distance($self->map($i,$j,$k), $self->map($i,$j+1,$k));  
							$dy += $temp ** 2;
							$by = 1;
						}
						if ($j < $self->{YDIM}-1 and $i < $self->{XDIM}-1) {
							# JCC $temp = $self->map($i,$j,$k) - $self->map($i+1,$j+1,$k);
                                                        # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i+1,$j+1,$k));
                                                        # $temp = $self-> distance_diff($diff); 
                                                        $temp = distance($self->map($i,$j,$k), $self->map($i+1,$j+1,$k));
							$dz1 += $temp ** 2;
                                                        # JCC $temp = $self->map($i,$j+1,$k) - $self->map($i+1,$j,$k);
                                                        # $diff = $self-> slow_diff($self->map($i,$j+1,$k), $self->map($i+1,$j,$k));
							# $temp = $self-> distance_diff($diff);
                                                        $temp = distance($self->map($i,$j+1,$k), $self->map($i+1,$j,$k));
							$dz2 += $temp ** 2;
							$bz=1;
						}
					}
					$dz = (sqrt($dz1)/sqrt(2.0)+sqrt($dz2)/sqrt(2.0))/2;
		    
					if ($bx) {
						$umat[2*$i+1+(2*$j)*($self->{XDIM}*2-1)] = sqrt($dx);
					}
					if ($by) {
						$umat[2*$i+(2*$j+1)*($self->{XDIM}*2-1)] = sqrt($dy);
					}
					if ($bz) {
						$umat[2*$i+1+(2*$j+1)*($self->{XDIM}*2-1)] = $dz;
					}
				}
			}
		}
		else {
		# Hexagonal topology 
			for $j (0..$self->{YDIM}-1) {
				for $i (0..$self->{XDIM}-1) {
					$dx=0; $dy=0; $dz=0; $count=0;
					$bx=0; $by=0; $bz=0;
					$temp=0;
					if ($i<$self->{XDIM}-1)
					{
						for $k (0..$self->{IDIM}-1) {
							# JCC $temp = $self->map($i,$j,$k) - $self->map($i+1,$j,$k);
                                                        # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i+1,$j,$k));
                                                        # $temp = $self-> distance_diff($diff);
                                                        $temp = distance($self->map($i,$j,$k), $self->map($i+1,$j,$k));  
							$dx += $temp ** 2;
							$bx = 1;
						}
					}
					$temp=0;
					if ($j < $self->{YDIM}-1) {
						if ($j%2) {
							for $k (0..$self->{IDIM}-1)
							{
								# JCC $temp = $self->map($i,$j,$k) - $self->map($i,$j+1,$k);
                                                                # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i,$j+1,$k));
                                                                # $temp = $self-> distance_diff($diff);
                                                                $temp = distance($self->map($i,$j,$k), $self->map($i,$j+1,$k));
								$dy += $temp ** 2;
								$by=1;
							}
						}
						else {
							if ($i>0) {
								for $k (0..$self->{IDIM}-1) {
									# JCC $temp = $self->map($i,$j,$k) - $self->map($i-1,$j+1,$k);
                                                                        # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i-1,$j+1,$k));
                                                                        # $temp = $self-> distance_diff($diff);
                                                                        $temp = distance($self->map($i,$j,$k), $self->map($i-1,$j+1,$k));
									$dy += $temp ** 2;
									$by=1;
								}
							}
							else {
								$temp=0;
							}
						}
					}
					$temp=0;
					if ($j < $self->{YDIM}-1) {
						if (!($j%2)) {
							for $k (0..$self->{IDIM}-1) {
								# JCC $temp = $self->map($i,$j,$k) - $self->map($i,$j+1,$k);
                                                                # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i,$j+1,$k));
                                                                # $temp = $self-> distance_diff($diff);
                                                                $temp = distance($self->map($i,$j,$k), $self->map($i,$j+1,$k));
								$dz += $temp ** 2;
							}
							$bz=1;
						}
						else {
							if ($i < $self->{XDIM}-1) {
								for $k (0..$self->{IDIM}-1) {
									# JCC $temp = $self->map($i,$j,$k) - $self->map($i+1,$j+1,$k);
                                                                        # my $diff = $self-> slow_diff($self->map($i,$j,$k), $self->map($i+1,$j+1,$k));
                                                                        # $temp = $self-> distance_diff($diff);
                                                                        $temp = distance($self->map($i,$j,$k), $self->map($i+1,$j+1,$k));
									$dz += $temp ** 2;
								}
								$bz=1;
							}
						}
					}
					else {
						$temp=0;
					}
				
					if ($bx) {
						$umat[2*$i+1+(2*$j)*($self->{XDIM}*2-1)] = sqrt($dx);
					}
	   	 	   if ($by) {
						if ($j%2) {
							$umat[2*$i+(2*$j+1)*($self->{XDIM}*2-1)] = sqrt($dy);
						}
						else {
							$umat[2*$i-1+(2*$j+1)*($self->{XDIM}*2-1)] = sqrt($dy);
						}
					}
					if ($bz) {
						if ($j%2) {
							$umat[2*$i+1+(2*$j+1)*($self->{XDIM}*2-1)] = sqrt($dz);
						}
						else {
							$umat[2*$i+(2*$j+1)*($self->{XDIM}*2-1)] = sqrt($dz);
						}
					}
				}
			}
		}
	
		# Set the values corresponding to the model vectors themselves
		# to medians of the surrounding values
		if ($self->{TOPOLOGY} eq 'rect') {
		# Rectangular topology
		# medians of the 4-neighborhood
			for ($j=0; $j<$self->{YDIM} * 2 - 1; $j+=2) {
				for ($i=0;$i<$self->{XDIM} * 2 - 1; $i+=2) {
					if($i>0 and $j>0 and $i<$self->{XDIM} * 2 - 2 and $j<$self->{YDIM} * 2 - 2) {
					# in the middle of the map
						$medtable[0] = $umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1] = $umat[$i+1+$j*($self->{XDIM}*2-1)];
						$medtable[2] = $umat[$i+($j-1)*($self->{XDIM}*2-1)];
						$medtable[3] = $umat[$i+($j+1)*($self->{XDIM}*2-1)];
						$#medtable = 3;
						@medtable = sort{$a <=> $b} @medtable;
						# Actually mean of two median values
						$umat[$i+$j*($self->{XDIM}*2-1)]=($medtable[1]+$medtable[2])/2.0;
					}
					elsif($j==0 and $i>0 and $i<$self->{XDIM} * 2 - 2) {
					# in the upper edge
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
						$#medtable = 2;
						@medtable = sort{$a<=>$b} @medtable;
						$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
					}
					elsif($j==$self->{YDIM} * 2 - 2 and $i>0 and $i<$self->{XDIM} * 2 - 2) {
					# in the lower edge
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						$medtable[2]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
						$#medtable = 2;
						@medtable = sort{$a<=>$b} @medtable;
						$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
					}
					elsif($i==0 and $j>0 and $j<$self->{YDIM} * 2 - 2) {
					# in the left edge
						$medtable[0]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
						$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
						$#medtable = 2;
						@medtable = sort{$a<=>$b} @medtable;
						$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
					}
					elsif($i==$self->{XDIM} * 2 - 2 and $j>0 and $j<$self->{YDIM} * 2 - 2) {
					# in the right edge
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
						$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
						$#medtable = 2;
						@medtable = sort{$a<=>$b} @medtable;
						$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
					}
					elsif($i==0 && $j==0) {
					# the upper left-hand corner
						$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i+1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j+1)*($self->{XDIM}*2-1)])/2.0;
					}
					elsif($i==$self->{XDIM} * 2 - 2 and $j==0) {
					# the upper right-hand corner
						$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i-1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j+1)*($self->{XDIM}*2-1)])/2.0;
					}
					elsif($i==0 and $j==$self->{YDIM} * 2 - 2) {
					# the lower left-hand corner
						$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i+1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j-1)*($self->{XDIM}*2-1)])/2.0;
					}
					elsif($i==$self->{XDIM} * 2 - 2 and $j==$self->{YDIM} * 2 - 2) {
					# the lower right-hand corner
						$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i-1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j-1)*($self->{XDIM}*2-1)])/2.0;
					}
				}
			}
		}
		else {
		# Hexagonal topology
			for ($j=0; $j<$self->{YDIM}*2-1; $j+=2) {
				for ($i=0; $i<$self->{XDIM}*2-1; $i+=2) {
					if($i>0 and $j>0 and $i<$self->{XDIM} * 2 - 2 and $j<$self->{YDIM} * 2 - 2) {
					# in the middle of the map
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						if(!($j%4)) {
							$medtable[2]=$umat[$i-1+($j-1)*($self->{XDIM}*2-1)];
							$medtable[3]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[4]=$umat[$i-1+($j+1)*($self->{XDIM}*2-1)];
							$medtable[5]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
						}
						else {
							$medtable[2]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[3]=$umat[$i+1+($j-1)*($self->{XDIM}*2-1)];
							$medtable[4]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
							$medtable[5]=$umat[$i+1+($j+1)*($self->{XDIM}*2-1)];
						}
						$#medtable = 5;
						@medtable = sort{$a<=>$b} @medtable;
						# Actually mean of two median values
						$umat[$i+$j*($self->{XDIM}*2-1)]=($medtable[2]+$medtable[3])/2;
					}
					elsif($j==0 and $i>0 and $i<$self->{XDIM} * 2 - 2) {
					# in the upper edge
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
						$medtable[3]=$umat[$i-1+($j+1)*($self->{XDIM}*2-1)];
						$#medtable = 3;
						@medtable = sort{$a<=>$b} @medtable;
						# Actually mean of two median values
						$umat[$i+$j*($self->{XDIM}*2-1)]=($medtable[1]+$medtable[2])/2;
					}
					elsif($j==$self->{YDIM} * 2 - 2 and $i>0 and $i<$self->{XDIM} * 2 - 2) {
					# in the lower edge
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						if(!($j%4)) {
							$medtable[2]=$umat[$i-1+($j-1)*($self->{XDIM}*2-1)];
							$medtable[3]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
						}
						else {
							$medtable[2]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[3]=$umat[$i+1+($j-1)*($self->{XDIM}*2-1)];
						}
						$#medtable = 3;
						@medtable = sort{$a<=>$b} @medtable;
						# Actually mean of two median values
						$umat[$i+$j*($self->{XDIM}*2-1)]=($medtable[1]+$medtable[2])/2;
					}
					elsif($i==0 and $j>0 and $j<$self->{YDIM} * 2 - 2) {
					# in the left edge
						$medtable[0]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
						if(!($j%4)) {
							$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
							$#medtable = 2;
							@medtable = sort{$a<=>$b} @medtable;
							$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
						}
						else {
							$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[2]=$umat[$i+1+($j-1)*($self->{XDIM}*2-1)];
							$medtable[3]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
							$medtable[4]=$umat[$i+1+($j+1)*($self->{XDIM}*2-1)];
							$#medtable = 4;
							@medtable = sort{$a<=>$b} @medtable;
							$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[2];
						}
					}
					elsif($i==$self->{XDIM} * 2 - 2 and $j>0 and $j<$self->{YDIM} * 2 - 2) {
					# in the right edge
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						if($j%4) {
							$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
							$#medtable = 2;
							@medtable = sort{$a<=>$b} @medtable;
							$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
						}
						else {
							$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[2]=$umat[$i-1+($j-1)*($self->{XDIM}*2-1)];
							$medtable[3]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
							$medtable[4]=$umat[$i-1+($j+1)*($self->{XDIM}*2-1)];
							$#medtable = 4;
							@medtable = sort{$a<=>$b} @medtable;
							$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[2];
						}
					}
					elsif($i==0 and $j==0) {
					# the upper left-hand corner
						$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i+1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j+1)*($self->{XDIM}*2-1)])/2.0;
					}
					elsif($i==$self->{XDIM} * 2 - 2 and $j==0) {
					# the upper right-hand corner
						$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
						$medtable[1]=$umat[$i-1+($j+1)*($self->{XDIM}*2-1)];
						$medtable[2]=$umat[$i+($j+1)*($self->{XDIM}*2-1)];
						$#medtable = 2;
						@medtable = sort{$a<=>$b} @medtable;
						$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
					}
					elsif($i==0 and $j==$self->{YDIM} * 2 - 2) {
					# the lower left-hand corner
						if(!($j%4)) {
							$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i+1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j-1)*($self->{XDIM}*2-1)])/2.0;
						}
						else {
							$medtable[0]=$umat[$i+1+$j*($self->{XDIM}*2-1)];
							$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[2]=$umat[$i+1+($j-1)*($self->{XDIM}*2-1)];
							$#medtable = 2;
							@medtable = sort{$a<=>$b} @medtable;
							$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
						}
					}
					elsif($i==$self->{XDIM} * 2 - 2 and $j==$self->{YDIM} * 2 - 2) {
					# the lower right-hand corner
						if($j%4) {
							$umat[$i+$j*($self->{XDIM}*2-1)]=($umat[$i-1+$j*($self->{XDIM}*2-1)]+$umat[$i+($j-1)*($self->{XDIM}*2-1)])/2.0;
						}
						else {
							$medtable[0]=$umat[$i-1+$j*($self->{XDIM}*2-1)];
							$medtable[1]=$umat[$i+($j-1)*($self->{XDIM}*2-1)];
							$medtable[2]=$umat[$i-1+($j-1)*($self->{XDIM}*2-1)];
							$#medtable = 2;
							@medtable = sort{$a<=>$b} @medtable;
							$umat[$i+$j*($self->{XDIM}*2-1)]=$medtable[1];
						}
					}
				}
			}
		}

		# scale values to (0..1)

                # JCC commented to test original distances
                # delete comments if necesary.

		my @umat_sort = sort{$a<=>$b} @umat;
		$bw = $umat_sort[$#umat_sort] - $umat_sort[0];
		$min = $umat_sort[0];
		for $i (0..$self->{XDIM} * 2 - 2) {
		 for $j (0..$self->{YDIM} * 2 - 2) {
			$umat[$i+$j*($self->{XDIM}*2-1)] = ($umat[$i+$j*($self->{XDIM}*2-1)]-$min)/$bw;
		 }
		}

		return \@umat;
	}

	##################################################
	#
	#
	#
	##################################################

	sub x_dim {
		my $self = shift;
		return $self->{XDIM};
	}

	sub y_dim {
		my $self = shift;
		return $self->{YDIM};
	}

	sub i_dim {
		my $self = shift;
		return $self->{IDIM};
	}

	sub topology {
		my $self = shift;
		return $self->{TOPOLOGY};
	}

	sub neighborhood {
		my $self = shift;
		return $self->{NEIGHBORHOOD};
	}

	sub map {
		my $self = shift;
		my ($x, $y, $z) = @_;
		return $self->{MAP}->[($y*$self->{XDIM} + $x) * $self->{IDIM} + $z];
	}

	sub label {
		my $self = shift;
		my ($x, $y) = @_;
		croak "Invalid argument" if (($x<0) or ($x>=$self->{XDIM}) or ($y<0) or ($y>=$self->{YDIM}));
		return $self->{LABELS}->[$y * $self->{XDIM} + $x];
	}

################################################################################
#
# "Private" methods.
#
################################################################################

        # JCC
        sub _round {
          my $number = shift;

          return sprintf("%.0f", $number); 
        }

        # JCC I have to change this method
	sub _find_two_eigenvectors_and_mean {
		my $self = shift;
		my $data = shift;

		my $k = 0;
		my $i = 0;
		my $j = 0;

		my $n = $self->{IDIM};

		my @r = ();
		my @m = ();
		my @u = ();
		my @v = ();
		my @k2 = ();
			  
		my @mu = ();
		my $patterns_count = @$data / $n;

		for ($k=0; $k<$patterns_count; $k++) {
			for ($i=0; $i<$n; $i++) {
			       	if ($data->[$i + $k * $n] =~ /^-?\d+\.?\d*$/) { # Is a real number
                                                                                # JCC must be a string
					$m[$i] += $data->[$i + $k * $n];
					$k2[$i]++;
				}
			}
		}
		
		$i = 0;
		foreach my $k2item (@k2) {
			$m[$i++] /= $k2item;
		}

		for ($k=0; $k < $patterns_count; $k++) {
			for ($i=0; $i<$n; $i++) {
				if ($data->[$k * $n + $i] =~ /^-?\d+\.?\d*$/) { # Is a real number
                                                                                # JCC must be a string
					for ($j=$i; $j<$n; $j++) {
						if ($data->[$k * $n + $j] =~ /^-?\d+\.?\d*$/) { # Is a real number
                                                                                                # JCC must be a string
                                                                                                # I have to implement "-" 
                                                                                                # and "*" operator for 
                                                                                                # strings   
							$r[$i * $n + $j] += ($data->[$k * $n + $i] - $m[$i]) * ($data->[$k * $n + $j] - $m[$j]);
						}
					}
				}
			}
		}

		for ($i=0; $i<$n; $i++) {
			for ($j=$i; $j<$n; $j++) {
                                # JCC $r[] contains string data. I have to implement "/" operator for data strings
				$r[$j * $n + $i]=$r[$i * $n + $j] /= $patterns_count;
			}
		}

		for ($i=0; $i<2; $i++) {
			for ($j=0; $j<$n; $j++) {
				$u[$i*$n+$j] = rand(2) - 1.0;
			}

			$self->_normalize(\@u, $i * $n);
			$mu[$i] = 1.0;
		}

		for ($k=0; $k<10; $k++) {
			for ($i=0; $i<2; $i++) {
				for ($j=0; $j<$n; $j++) {
					$v[$i * $n + $j] = $mu[$i] * $self->_inner_product(\@r, $j*$n, \@u, $i*$n, $n) + $u[$i * $n + $j];
				}
			}

			$self->_gram_schmidt(\@v, $n, 2);
			my $sum = 0.0;
    
			for ($i=0; $i<2; $i++) {
				for ($j=0; $j<$n; $j++) {
					$sum += abs($v[$i * $n + $j] / $self->_inner_product(\@r, $j*$n, \@v, $i*$n, $n));
				}
				$mu[$i] = $sum / $n;
			}
			@u = @v;
		}

		my @eigen1 = ();
		my @eigen2 = ();

    	for ($j=0; $j<$n; $j++) {
			$eigen1[$j] = $u[$j] / sqrt($mu[0]);
		}
	   for ($j=0; $j<$n; $j++) {
			$eigen2[$j] = $u[$j+$n] / sqrt($mu[1]);
		}

		return \(@eigen1, @eigen2, @m)
	}

	sub _inner_product {
		my $self = shift;
		my ($data1, $start_index1, $data2, $start_index2, $count) = @_;

		my $sum = 0;
		for (my $i=0; $i<$count; $i++) {
                        # JCC probably another change needed to "*" two strings
			$sum += $data1->[$start_index1++] * $data2->[$start_index2++]
		}
		return $sum;
	}

	sub _normalize {
		my $self = shift;
		my $data = shift;
		my $start_index = shift;

		my $sum = sqrt($self->_inner_product($data, $start_index, $data, $start_index, $self->{IDIM}));

		for (my $i=$start_index; $i<$start_index + $self->{IDIM}; $i++) {
			$data->[$i] /= $sum;
		}
	}

	sub _gram_schmidt {
		my $self = shift;
		my $data = shift;
		my $n = shift;
		my $e = shift;

		my @w = ();
		my $sum = 0;

		for (my $i=0; $i<$e; $i++) {
			for (my $t=0; $t<$n; $t++) {
				$sum = $data->[$i * $n + $t];
					for (my $j=0; $j<$i; $j++) {
						for (my $p=0; $p<$n; $p++) {
                                                        # JCC "-" and "*" operator for strings 
							$sum -= $w[$j * $n + $t] * $w[$j * $n + $p] * $data->[$i * $n + $p];
						}
					}
				$w[$i * $n + $t] = $sum;
			}
			$self->_normalize(\@w, $i * $n);
		}
		@$data = @w;
	}

	sub _get_hexa_dist {
		my $self = shift;
		my ($bx, $by, $tx, $ty) = @_;

		my $diff = $bx - $tx;

		if ((($by - $ty) % 2) != 0) {
			if (($by % 2) == 0) {
				$diff -= 0.5;
			}
			else {
				$diff += 0.5;
			}
		}
  
		my $temp = $diff ** 2;
		$diff = $by - $ty;
		$temp += 0.75 * $diff ** 2;
		return sqrt($temp);
	}

	sub _get_rect_dist {
		my $self = shift;
		my ($bx, $by, $tx, $ty) = @_;

		my $diff = $bx - $tx;
		my $temp = $diff ** 2;
		$diff = $by - $ty;
		$temp += $diff ** 2;
		return sqrt($temp);
	}

        # JCC Modified
	sub _adapt_bubble {
		my $self = shift;
		my ($bx, $by, $radius, $alpha, $data) = @_;
                my $modified = 0;

		my $dist_func;
		if ($self->{TOPOLOGY} eq 'rect') {
			$dist_func = "_get_rect_dist";			
		}
		else {
			$dist_func = "_get_hexa_dist";			
		}

		for(my $x=0; $x<$self->{XDIM}; $x++) {
			for(my $y=0; $y<$self->{YDIM}; $y++) {
				if ($self->$dist_func($bx, $by, $x, $y) <= $radius) {
					for (my $i=0; $i<$self->{IDIM}; $i++) {
						# if ($data->[$i] =~ /^-?\d+\.?\d*$/) { # Is a real number
                                                                                      # JCC string value
                                                        # $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i] += 
							# 	$alpha * ($data->[$i] - $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i]);
                                                        my $map_data          = $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i];
                                                        my $input_data        = $data->[$i];
                                                        my $diff              = $self-> slow_diff($map_data, $input_data); 
                                                        my $distance          = $self-> distance_diff($diff);
                                                        # my $distance          = distance($map_data, $input_data); 
                                                        my $new_distance      = _round($alpha * $distance);
                                                        my $new_string        = new_string_diff($new_distance, $map_data, $input_data, $diff);
                                                        if ($new_string ne $map_data) {
                                                          $modified = 1;
                                                        }
                                                        $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i] = $new_string;
						# }
					}
				}
			}
		}
                return $modified;
	}
         
        # JCC Modified
	sub _adapt_gaussian {
		my $self = shift;
		my ($bx, $by, $radius, $alpha, $data) = @_;

		my $dist_func;
		if ($self->{TOPOLOGY} eq 'rect') {
			$dist_func = "_get_rect_dist";			
		}
		else {
			$dist_func = "_get_hexa_dist";
		}

		for(my $x=0; $x<$self->{XDIM}; $x++) {
			for(my $y=0; $y<$self->{YDIM}; $y++) {
				my $dd = $self->$dist_func($bx, $by, $x, $y);
				my $alp = $alpha * exp(-$dd ** 2 / (2.0 * $radius ** 2)); # -$dd**2 - ????
				for (my $i=0; $i<$self->{IDIM}; $i++) {
				        # if ($data->[$i] =~ /^-?\d+\.?\d*$/) { # Is a real number
                                                                              # JCC a string
						# $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i] += 
						# 	$alp * ($data->[$i] - $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i]);
                                                my $map_data     = $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i];
                                                my $input_data   = $data->[$i];
                                                my $diff         = $self-> slow_diff($map_data, $input_data);
                                                my $distance     = $self-> distance_diff($diff);
                                                # my $distance          = distance($map_data, $input_data); 
                                                my $new_distance = _round($alpha * $distance);
                                                my $new_string   = new_string_diff($new_distance, $map_data, $input_data, $diff);
                                                $self->{MAP}->[($y * $self->{XDIM} + $x) * $self->{IDIM} + $i] = $new_string;
					#}
				}
			}
		}
	}

	sub _alpha_linear {
		my $self = shift;
		my ($iter, $epoches, $alpha) = @_;              
		return $alpha * ($epoches - $iter) / $epoches;

	}

	sub _alpha_inverse_t {
		my $self = shift;
		my ($iter, $epoches, $alpha) = @_;
		my $c = $epoches / $AI::NeuralNet::SOMString::INV_ALPHA_CONSTANT;
		return $alpha * $c /($c + $iter) / $epoches;
	}

1;

__END__


=head1 NAME

AI::NeuralNet::SOMString - A simple Kohonen Self-Organizing Maps with strings input data.

=head1 SYNOPSIS

use AI::NeuralNet::SOMString;
	
	# Create a new self-organizing map.
	$som = AI::NeuralNet::SOMString->new();
	
	# Create a data set to initialize and train.
	@data = (
	"a", "ab", "abc", "abcd", "abcde");

	# Initialize map.
	$som->initialize(3,3,5,'hexa','bubble','random',0,\@data);
        # only random initialization type is supported

	# Find quantization error before training and print it.
	$qerr = $som->qerror(\@data);
	print "Mean quantization error before trainig= $qerr\n";

	# Train map with the same data set.
	$som->train(20,0.25,3,'linear',\@data);

	# Find quantization error after training and print it.
	$qerr = $som->qerror(\@data);
	print "Mean quantization error after trainig= $qerr\n\n";

	# Create a data set to label map.
	@label_data = (
	23.508335, 21.359016, 3.906102, 4.884908, 404.440765,
	23.823174, 21.731325, 4.295785, 5.244288, 405.100342,
	24.207268, 22.070162, 4.646249, 5.030964, 404.812225,
	24.284208, 22.401424, 4.806539, 5.006081, 404.735596,
	24.401838, 22.588514, 4.957213, 5.011020, 404.176880,
	25.824610, 24.155489, 5.976608, 6.708979, 405.040466,
	26.197090, 24.353720, 6.272694, 6.843574, 405.728119,
	26.347252, 24.720333, 6.518201, 6.950599, 405.758606,
	26.537718, 24.976704, 6.661457, 7.163557, 404.037567,
	27.041384, 25.309855, 6.979992, 7.488787, 404.839081,
	27.193167, 25.601683, 7.173965, 7.920047, 404.749054);

	#Label map with "fault" patterns.
	$patterns_count = scalar(@label_data) / $som->i_dim;
	for $i (0..$patterns_count-1){
		@pattern = splice(@label_data, 0, $som->i_dim);
		($x, $y) = $som->winner(\@pattern);
		$som->set_label($x, $y, "fault");
	}

	# Create a data set to test map.
	@test_data = (
	23.508335, 21.359016, 3.906102, 4.884908, X,
	23.823174, 21.731325, 4.295785, 5.244288, 405.100342,
	24.207268, 22.070162, 4.646249, 5.030964, 404.812225,
	13.575570, 12.656892, -1.424328, -2.302774, 404.921600,
	24.284208, 22.401424, 4.806539, 5.006081, 404.735596,
	24.401838, 22.588514, 4.957213, 5.011020, 404.176880,
	13.844373, 12.610620, -1.435429, -1.964423, 404.978180,
	24.628309, 23.015909, 5.075150, 5.560286, 403.773132,
	13.996934, 12.669785, -1.384147, -1.830788, 405.187378,
	25.551638, 23.864803, 5.774306, 6.208019, 403.946777,
	26.347252, 24.720333, 6.518201, 6.950599, 405.758606,
	26.537718, 24.976704, 6.661457, 7.163557, 404.037567,
	X, 15.601683, X, X, 404.749054,
	27.041384, 25.309855, 6.979992, 7.488787, 404.839081);

	#Test map and print results.
	$patterns_count = scalar(@test_data) / $som->i_dim;
	for $i (0..$patterns_count-1){
		@pattern = splice(@test_data, 0, $som->i_dim);
		($x, $y) = $som->winner(\@pattern);
		$label=$som->label($x, $y);
		if (defined($label)) {
			print "@pattern - $label\n";
		}
		else {
			print "@pattern\n";
		}
	}

=head1 DESCRIPTION

=over 4

=item The principle of the SOM

The Self-Organizing Map represents the result of a vector quantization
algorithm that places a number reference or of codebook vectors into
a high-dimensional input data space to approximate to its data sets
in an ordered fashion. When local-order relations are defined between
the reference vectors, the relative values of the latter are made to
depend on each other as if their neighboring values would lie along an
"elastic surface". By means of the self-organizing algorithm, this
"surface" becomes defined as a kind of nonlinear regression of the
reference vectors through the data points. A mapping from a
high-dimensional data space R^n onto, say, a two-dimensional lattice of
points is thereby also defined. Such a mapping can effectively be used
to visualize metric ordering relations of input samples. In
practice, the mapping is obtained as an asymptotic state in a learning
process.

A typical application of this kind of SOM is in the analysis of
complex experimental vectorial data such as process states, where
the data elements may even be related to each other in a highly
nonlinear fashion.

There exist many versions of the SOM. The basic philosophy, however,
is very simple and already effective as such, and has been implemented
by the procedures contained in this package.

The SOM here defines a mapping from the input data space R^n onto a
regular two-dimensional array of nodes.  With every node i, a
parametric reference vector mi in R^n is associated.  The lattice type of
the array can be defined as rectangular or hexagonal in this package;
the latter is more effective for visual display. An input vector x in
R^n is compared with the mi, and the best match is defined as
"winner": the input is thus mapped onto this location.

One might say that the SOM is a "nonlinear projection" of the probability
density function of the high-dimensional input data onto the
two-dimensional display. Let x in R^n be an input data vector. It may be
compared with all the mi in any metric; in practical applications, the
smallest of the Euclidean distances ||x - mi|| is usually made to define
the best-matching node, signified by the subscript c:

B<||x - mc|| = min{||x - mi||} ; or>

B<c  =   arg min{||x - mi||} ; (1)>

Thus x is mapped onto the node c relative to the parameter values mi.

During learning, those nodes that are topographically close in the
array up to a certain distance will activate each other to learn from
the same input.  Without mathematical proof we state that useful
values of the mi can be found as convergence limits of the following
learning process, whereby the initial values of the mi(0) can be
arbitrary, e.g., random:

B<mi(t + 1) = mi(t) + hci(t)[x(t) - mi(t)] ; (2)>

where t is an integer, the discrete-time coordinate, and hci(t) is
the so-called neighborhood kernel; it is a function defined over the
lattice points. Usually hci(t) = h(||rc - ri||; t), where rc in R^2 and
ri in R^2 are the radius vectors of nodes c and i, respectively, in the
array. With increasing ||rc - ri||, hci goes to 0. The average width and
form of hci defines the "stiffness" of the "elastic surface" to be
fitted to the data points. Notice that it is usually not desirable to
describe the exact form of p(x), especially if x is very-high-dimensional;
it is more important to be able to automatically find those dimensions and
domains in the signal space where x has significant amounts of sample values!

This package contains two options for the definition of hci(t). The simpler
of them refers to a neighborhood set of array points around node c. Let this
index set be denoted Nc (notice that we can define Nc = Nc(t) as a function
of time), whereby hci = alpha(t) if i in Nc and hci = 0 if i not in Nc, where
alpha(t) is some monotonically decreasing function of time (0 E<lt> alpha(t) E<lt> 1).
This kind of kernel is nicknamed "bubble", because it relates to certain
activity "bubbles" in laterally connected neural networks [Kohonen 1989].
Another widely applied neighborhood kernel can be written in terms of the
Gaussian function,

B<hci = alpha(t) * exp(-(||rc-ri||^2)/(2 rad^2(t))); (3)>

where  alpha(t) is another scalar-valued "learning rate", and the
parameter rad(t) defines the width of the kernel; the latter
corresponds to the radius of Nc above. Both alpha(t) and rad(t) are
some monotonically decreasing functions of time, and their exact forms
are not critical; they could thus be selected linear.  In this package
it is furher possible to use a function of the type alpha(t) = A/(B + t),
where A and B are constants; the inverse-time function is
justified theoretically, approximately at least, by the so-called
stochastic approximation theory.  It is advisable to use the inverse-time
type function with large maps and long training runs, to allow more
balanced finetuning of the reference vectors. Effective choices for
these functions and their parameters have so far only been
determined experimentally; such default definitions have been used in
this package.

The next step is calibration of the map, in order to be able to locate
images of different input data items on it. In the practical
applications for which such maps are intended, it may be usually
self-evident from daily routines how a particular input data set ought
to be interpreted.  By inputting a number of typical, manually
analyzed data sets and looking where the best matches on the map
according to Eq.  (1) lie, the map or at least a subset of its nodes
can be labeled to delineate a "coordinate system" or at least a set of
characteristic reference points on it according to their manual
interpretation.  Since this mapping is assumed to be continuous along
some hypothetical "elastic surface", it may be self-evident how the
unknown data are interpreted by means of interpolation and
extrapolation with respect to these calibrated points.

=back

=head2 METHODS

=over 4

=item new AI::NeuralNet::SOMString;

Creates a new empty Self-Organizing Map object;

=item $som-E<gt>initialize($xdim, $ydim, $idim, $topology, $neighborhood, $init_type, $random_seed, \@data);

Initializes the SOM object. Sets map dimension $xdim x $ydim. Input data vector sets equal to $idim.
Variable $topology may be either "rect" or "hexa", $neighborhood may be "bubble" or "gaussian".
Initialization type of the SOM object can be "linear" or "random", $random seed is any non-negative 
integer. \@data is a reference to the array containing initialization data.

=item $som-E<gt>train($train_length, $alpha, $radius, $alpha_type, \@data);

The method trains the Self-Organizing Map.
$train_length - a number of training epoches, $alpha - learning rate, $radius - initial training radius
which decreases to 1 during training process, $alpha_type sets a type of the learning rate decrease function, and can be "linear" or
"inverse_t", \@data is a reference to the array containing training data.

=item $som-E<gt>qerror;

Returns quantization error of the trained map.

=item ($x, $y, $dist) = $som-E<gt>winner(\@data);

Finds the "winned" neuron for the mapped data vector \@data and returns its coordinates $x and $y and $dist - Euclidean 
distance between the neuron and the input vector.

=item $som-E<gt>set_label($x, $y, $label);

Sets label for the neuron with the coordinates x and y

=item $som-E<gt>clear_all_labels;

Clears all the labels on the map.

=item $som-E<gt>save(*FILE);

Save the Self-Organazing Map to file which represented as descriptor *FILE.
This may be *STDOUT.
The reference vectors are stored in ASCII-form. The format of the
entries is similar to that used in the input data files, except that
the optional iitems on the first line of data files (topology type, x-
and y-dimensions and neighborhood type) are now compulsory. In map
files it is possible to include several labels for each entry.

An example: The map file code.cod contains a map of three-dimensional
vectors, with three times two map units.

      code.cod:

       3 hexa 3 2 bubble
       191.105   199.014   21.6269
       215.389   156.693   63.8977
       242.999   111.141   106.704
       241.07    214.011   44.4638
       231.183   140.824   67.8754
       217.914   71.7228   90.2189


The x-coordinates of the map (column numbers) may be thought to range
from 0 to n 1, where n is the x-dimension of the map, and the
y-coordinates (row numbers) from 0 to m 1, respectively, where m is
the y-dimension of the map. The reference vectors of the map are
stored in the map file in the following order:

 1       The unit with coordinates (0; 0).
 2       The unit with coordinates (1; 0).
         ...
 n       The unit with coordinates (n - 1; 0).
 n + 1   The unit with coordinates (0; 1).
         ...
 nm      The last unit is the one with coordinates (n - 1; m - 1).


    (0,0) - (1,0) - (2,0) - (3,0)         (0,0) - (1,0) - (2,0) - (3,0)

      |       |       |       |               \    /   \  /   \   /   \

    (0,1) - (1,1) - (2,1) - (3,1)             (0,1) - (1,1) - (2,1) - (3,1)

      |       |       |       |                 /   \  /   \   /   \  /

    (0,2) - (1,2) - (2,2) - (3,2)         (0,2) - (1,2) - (2,2)  -(3,2)



          Rectangular                             Hexagonal


In the picture above the locations of the units in the two possible
topological structures are shown. The distance between two units in
the map is computed as an Euclidean distance in the (two dimensional)
map topology.

=item $som-E<gt>load(*FILE);

Loads the Self-Organazing Map from file which represented as descriptor *FILE.

=item $som-E<gt>umatrix;

Calculates Umatrix for existing map and returns a reference to array that contains Umatrix data.

Umatrix is a way of representing the distances between reference vectors of neighboring map units.
Although being a somewhat laborious task to calculate it can effectively be used to visualize the
map in an interpretable manner.

Umatrix algorithm calculates the distances between the neighboring neurons and stores them
in a grid (matrix) that corresponds to the used topology type. From that grid, a proper
visualization can be generated by picking the values for each neuron distance
(4 for rectangular and 6 for hexagonal topology). The distance values are scaled to the range
between 0 and 1 and are shown as colors when the Umatrix is visualized.

Example:

	...
	$umat = $som->umatrix;
	for $j (0..$som->y_dim*2-2) {
		for $i (0..$som->x_dim*2-2) {
			print "$umat->[$j*($som->x_dim*2-1)+$i] ";
		}
		print "\n";
	}
	...

=item $som-E<gt>x_dim;

Returns the x dimention of map.

=item $som-E<gt>y_dim;

Returns the y dimension of map.

=item $som-E<gt>i_dim;

Returns the input vector dimension

=item $som-E<gt>topology;

Returns the map topology.

=item $som-E<gt>neighborhood;

Returns the neighborhood function type.

=item $som-E<gt>map($x, $y, $z);

Returns the $z element of the vector of the neuron with coordinates $x and $y. 
0 E<lt> $z E<lt>= $som-E<gt>i_dim.

=item $som-E<gt>label($x, $y);

Returns the label corresponding to the neuron with coordinates $x and $y.

=back

=head1 NOTES

=over 4

=item Using missing values

You can use missing values in datasets to initialize and train map. I recommend to use "X" symbol
to indicate missing values, but you can use any alpha symbols for this purpose.

Some particular parts of this documentation were taken from the documentation for SOM_PAK
F<E<lt>http://www.cis.hut.fi/research/som-research/nnrc-programs.shtmlE<gt>>.

=back

=head1 BUGS

This is the alpha release of C<AI::NeuralNet::SOM>, but I am sure 
there are probably bugs in here which I just have not found yet. If you find bugs in this module, I would 
appreciate it greatly if you could report them to me at F<E<lt>voischev@mail.ruE<gt>>,
or, even better, try to patch them yourself and figure out why the bug is being buggy, and
send me the patched code, again at F<E<lt>voischev@mail.ruE<gt>>. 

=head1 HISTORY

AI-NeuralNet-SOM-0.01 - The first alpha version.

AI-NeuralNet-SOM-0.02 - fixed bugs in "load" method and added new method "umatrix".

=head1 AUTHOR

Jose Carpio F<E<lt>jose.carpio@dti.uhu.esE<gt>> adaptation for strings data input of  C<AI::NeuralNet::SOM> 

created by Voischev Alexander F<E<lt>voischev@mail.ruE<gt>>

Copyright (c) 2008 Jose Carpio. All rights reserved. The C<AI::NeuralNet::SOMString> are free software; 
you can redistribute it and/or modify it under the same terms as Perl itself.
THIS COME WITHOUT WARRANTY OF ANY KIND.

=cut
