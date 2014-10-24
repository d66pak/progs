#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my $carSales;

$carSales = {
  '1980' => {
    'maruti' => {
      '800' => {
        'red' => 5000,
      }
    },
    'fiat' => {
      'punto' => {
        'black' => 6000,
        'red' => 7000,
      },
    },
  },
  '1985' => {
    'jeep' => {
      'blue' => 1000,
    },
    'maruti' => {
      '800' => {
        'red' => 8900,
        'blue' => 7000,
      }
    },
  },
};

sub soldOnYear($)
{
  my ($year) = @_;

  my $sold = 0;

  if (defined $carSales->{$year}) {

    my $year_ref = $carSales->{$year};

    foreach my $car (keys %$year_ref) {

      print "$car\n";

      my $car_ref = $year_ref->{$car};

      foreach my $make (keys %$car_ref) {

        print "$make\n";

        my $make_ref = $car_ref->{$make};

        foreach my $color (keys %$make_ref) {

          print "$color\n";

          $sold += $make_ref->{$color};

        }
      }
    }
  }

  return $sold;
}
print Dumper($carSales) . "\n";

print soldOnYear('1985') . "\n";


