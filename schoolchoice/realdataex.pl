#!/usr/bin/perl -w
use List::Util qw(max min);
use POSIX qw(ceil floor);
use Statistics::Distributions (uprob);
use Excel::Writer::XLSX;
use Spreadsheet::Read;
use Storable qw(dclone);

$minimum_score = 0;
$maximum_score = 750;
$majority_ratio = 0.85;
$majority_quota = 0.85;
$student_number = 40000;
$score_mean = 450;
$score_sd = 60;
$school_number = 217;
#$school_quota = 25;
$score_diff =15;
$score_bonus = 15;
$loop_number = 2;

$realdata = ReadData("realdata.xlsx");

$school_quota = $realdata->[1]{cell}[2];
$school_type = $realdata->[1]{cell}[5];

$schooltype_value =
{'1' => 50,
 '2' => 60,
 '3' => 70,
 '4' => 80,
 '5' => 90,
};




sub normaldist {
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
        $u2 = 2 * rand() - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;
    # return both if wanted, else just one
    return $g1;
}




sub gentype {
    my $probability = shift ;
    my $temp = rand();
    if($temp < $probability){
        return 1;
    }else{
        return 0;
    }
}


sub genscore {
    my ($mu, $sigma,$racetype) = @_;
    my $score;
    do {
	if($racetype)
	{$score = $mu + &normaldist * $sigma;}
	else{$score = $mu - $score_diff + &normaldist * $sigma;}
    }
    while($score<$minimum_score or $score>$maximum_score);
    return $score;
}





sub genschoolvalues{

    my @schoolvalues;
    for(my $i = 1; $i <= $school_number; $i++){
	$schoolvalues[$i]=(rand() - 0.5)*20 + $schooltype_value->{$school_type->[$i]};
    }

    return \@schoolvalues;

}





sub genenvironment {

    my %studenttable = ();
    my @race=();
    for(my $i = 0; $i < $student_number; ++$i)
    {
	my (@race,@schoolvalues,@schoolrankings);
	$race[$i]=&gentype($majority_ratio);
	$schoolvalues = genschoolvalues();
	@schoolrankings= sort { $schoolvalues->[$b]<=>$schoolvalues->[$a] } (1..$school_number);

	$studenttable{$i}=
	{
	    race => $race[$i],
	    score => &genscore($score_mean, $score_sd, $race[$i]),

	    schoolrankings => \@schoolrankings,

	    assigned => '0',

	    schoolpreference => '1000',
	};


    }


    return \%studenttable;
}

#the benchmark mechanism follows
sub benchmarkC
{
    my $table = shift;

    my  $stutab =dclone $table; #get a copy to process in the function and return
    my @leaguetable = sort {$stutab->{$b}{score}<=>$stutab->{$a}{score}}(0..$student_number-1);

    my %schoolquota  = my %recruits =();

    for(my $school=1; $school<= $school_number; $school++)
    {

	$schoolquota{$school} = $school_quota->[$school];

    }



    foreach my $student (@leaguetable)
    {

	for(my $i = 0; $i < $school_number; ++$i)
	{
	    my $school = $stutab->{$student}{schoolrankings}[$i];

	    if($schoolquota{$school}>0)
	    {
		push @{$recruits{$school}}, $student;
		$stutab->{$student}{assigned}=$school;
		$schoolquota{$school}--;
		$stutab->{$student}{schoolpreference}=$i+1;
		last;
	    }
	}
    }





    return $stutab;
}
#scoreplus
sub scoreplusC
{
    my $table = shift ;
    my $stutab = dclone $table;


    for(my $i=0;$i<$student_number; $i++)
    {
	if($stutab->{$i}{race}==0){
	    $stutab->{$i}{score} += $score_bonus;
	}
    }
    my @leaguetable = sort {$stutab->{$b}{score}<=>$stutab->{$a}{score}}(0..$student_number-1);


    my %schoolquota  = my %recruits =();

    for(my $school=1; $school<= $school_number; $school++)
    {

	$schoolquota{$school} = $school_quota->[$school];

    }



    foreach my $student (@leaguetable)
    {

	for(my $i = 0; $i < $school_number; ++$i)
	{
	    my $school = $stutab->{$student}{schoolrankings}[$i];

	    if($schoolquota{$school}>0)
	    {
		push @{$recruits{$school}}, $student;
		$stutab->{$student}{assigned}=$school;
		$schoolquota{$school}--;
		$stutab->{$student}{schoolpreference}=$i+1;
		last;
	    }
	}
    }




    return $stutab;
}
#majority quota

sub majorityquotaC
{
    my $table = shift ;
    my $stutab = dclone $table;
    #sort students according to their scores
    my @leaguetable = sort {$stutab->{$b}{score}<=>$stutab->{$a}{score}}(0..$student_number-1);

    my %schoolquota  = my %recruits = my %schoolmajorityquota = ();

    for(my $school=1; $school<= $school_number; $school++)
    {

	$schoolquota{$school} = $school_quota->[$school];
	$schoolmajorityquota{$school} = ceil($majority_quota *  $school_quota->[$school]);

    }

    foreach my $student (@leaguetable)
    {
	if($stutab->{$student}{race}==0){
            for(my $i = 0; $i < $school_number; ++$i)
            {
		my $school = $stutab->{$student}{schoolrankings}[$i];

		if($schoolquota{$school}>0 )
                {
                    push @{$recruits{$school}}, $student;
		    $stutab->{$student}{assigned}=$school;
                    $schoolquota{$school}--;
                    $stutab->{$student}{schoolpreference}=$i+1;
                    last;
		}
            }
	}else{
	    for(my $i = 0; $i < $school_number; ++$i)
            {
		my $school = $stutab->{$student}{schoolrankings}[$i];
		if($schoolquota{$school}>0 and $schoolmajorityquota{$school}>0 )
		{
		    push @{$recruits{$school}}, $student;
		    $stutab->{$student}{assigned}=$school;
		    $schoolmajorityquota{$school}--;
		    $schoolquota{$school}--;
		    $stutab->{$student}{schoolpreference}=$i+1;
		    last;
		}
            }

	}
    }





    return $stutab;
}





#   is subroutine calculates three different types (No Affirmative Action, Majority Quotas	#
# and minority reserves) of Deferred Acceptance Algorithm.									#
# Variables:
# $studentpreference: A link to the student preferences hash
# $schoolpreference: A link to the school preferences hash
# $minoritystatus: Minority status of the students
# $schoolquota: School quota size
# $minorityquota: minority quota size
#############################################################################################
sub galeshapleyMinorityReserve {

    my $table = shift ;
    my $stutab=dclone $table;
    my $gstutab= dclone $stutab;
    # my ( %studentpreference, %schoolpreference, $minoritystatus, $schoolquota, $minorityquota);
    my %gschoolpreference = ();
    foreach my $student (0..$student_number-1){
	if($gstutab->{$student}{race}==1){
	    my @gschoolrankings = map {$_, $_+$school_number} @{$gstutab->{$student}{schoolrankings}};
	    $gstutab->{$student}{schoolrankings } = \@gschoolrankings;

	}else{
	    my @gschoolrankings = map {$_+$school_number, $_} @{$gstutab->{$student}{schoolrankings}};
	    $gstutab->{$student}{schoolrankings } = \@gschoolrankings;
	}
    }
    foreach my $gschool (1..$school_number){
	my @leaguetable  =   sort {$stutab->{$b}{score}<=>$stutab->{$a}{score}}(0..$student_number-1);
	my $i = 0;
	$gschoolpreference{$gschool} = {map { $_, $i++} @leaguetable};
    }
    foreach my $gschool ($school_number+1..2*$school_number){
	my @leaguetableminor = sort {$stutab->{$b}{score}<=>$stutab->{$a}{score}} grep {$gstutab->{$_}{race}==0} (0..$student_number-1);
	my @leaguetablemajor = sort {$stutab->{$b}{score}<=>$stutab->{$a}{score}} grep {$gstutab->{$_}{race}==1} (0..$student_number-1);
	my @leaguetable= (@leaguetableminor, @leaguetablemajor);
	my $i = 0;
	$gschoolpreference{$gschool} = {map {$_, $i++} @leaguetable};
    }


    for(my $school=1; $school<= $school_number; $school++)
    {
	$gschoolquota{$school} = ceil($majority_quota *  $school_quota->[$school]);
    }
    for(my $school=$school_number+1; $school<= 2*$school_number; $school++)
    {
	$gschoolquota{$school} = $school_quota->[$school-$school_number] - ceil($majority_quota *  $school_quota->[$school-$school_number]);
    }

    my  $notfinished = 1;
    my %candidates = ();

    while($notfinished)
    {
	$notfinished = 0;
	foreach my $student (grep {$gstutab->{$_}{assigned} == 0} (0..$student_number-1))
	{
	    my $favorite = shift  @{$gstutab->{$student}{schoolrankings}};
	    push @{$candidates{$favorite}}, $student if defined $favorite;
	}

	foreach my $gschool  (keys %candidates)
	{
	    print "$gschool\n" if !exists $gschoolquota{$gschool};
	    if(@{$candidates{$gschool}} > $gschoolquota{$gschool})
	    {
            $notfinished = 1;
            my	$count = 0;
            my @tmp = sort {$gschoolpreference{$gschool}{$a} <=> $gschoolpreference{$gschool}{$b}} @{$candidates{$gschool}};
            @{$candidates{$gschool}}= @tmp[(0..$gschoolquota{$gschool}-1)];
            foreach my $student (@tmp)
            {
                $count++;
                if($count > $gschoolquota{$gschool}) {
                    $gstutab->{$student}{assigned}=0;



                }else{
                    $gstutab->{$student}{assigned}=$gschool;
                }
            }
	    }else{
            foreach my $student (@{$candidates{$gschool}}){
                $gstutab->{$student}{assigned}=$gschool;
            }
        }
	}
    }
    for(my $student = 0; $student < $student_number; $student++) {
	if($gstutab->{$student}{assigned}>$school_number){
	    $stutab->{$student}{assigned} = $gstutab->{$student}{assigned} -$school_number;
	    my $i=1;
	    my %sturank = map {$_,$i++} @{$stutab->{$student}{schoolrankings}};
        $sturank{0}=1000;
	    $stutab->{$student}{schoolpreference}= $sturank{$stutab->{$student}{assigned}};

	}else{
	    $stutab->{$student}{assigned} = $gstutab->{$student}{assigned};
	    my $i=1;
	    my %sturank = map {$_,$i++} @{$stutab->{$student}{schoolrankings}};
        $sturank{0}=1000;
	    $stutab->{$student}{schoolpreference}= $sturank{$stutab->{$student}{assigned}};
	}
    }




    return $stutab;
}
=sub paralellMinorityReserve{
    my $table = shift ;
    my $stutab=dclone $table;
    my $gstutab= dclone $stutab;
}
=cut
sub writeExcel{
    my $name = shift;
    my %table = ();
    $table{benchmark} = shift;
    $table{scoreplus} = shift;
    $table{majorityquota}= shift;
    $table{minorityreserve}= shift;

    my $workbook = Excel::Writer::XLSX->new($name.".xlsx");
    $format = $workbook->add_format();
    $format->set_bold();
    $format->set_color('purple');
    $format->set_align('center');

    foreach my $model (qw(benchmark scoreplus majorityquota minorityreserve)){
	$worksheet =  $workbook->add_worksheet();



	$col=$row=0;


	$worksheet->write($row,$col,'ID',$format);
	$worksheet->write($row,$col+1,'race',$format);
	$worksheet->write($row,$col+2,'assigned',$format);
	$worksheet->write($row,$col+3,'score',$format);
	$worksheet->write($row,$col+4,'schoolpreferenceranking',$format);
	$worksheet->write($row,$col+5,'schooltype',$format);

	for(my $i=0; $i < $student_number; ++$i)
	{
	    $worksheet->write($row+$i+1,$col,$i);
	    $worksheet->write($row+$i+1,$col+1,$table{$model}->{$i}{race});
	    $worksheet->write($row+$i+1,$col+2,$table{$model}->{$i}{assigned},$format);
	    $worksheet->write($row+$i+1,$col+3,$table{$model}->{$i}{score},$format);
	    $worksheet->write($row+$i+1,$col+4,$table{$model}->{$i}{schoolpreference},$format);

	    $worksheet->write($row+$i+1,$col+5,$school_type->[$table{$model}->{$i}{assigned}],$format);
	}
    }
}

for(my $k=0; $k < $loop_number; ++$k)
{
    $league_table=&genenvironment();

    $table{$k}{benchmark}=&benchmarkC($league_table);
    $table{$k}{scoreplus}=&scoreplusC($league_table);
    $table{$k}{majorityquota}=&majorityquotaC($league_table);
    $table{$k}{minorityreserve}=&galeshapleyMinorityReserve ($league_table);


   # &writeExcel("simulation$k",$table{$k}{benchmark},$table{$k}{scoreplus},$table{$k}{majorityquota},$table{$k}{minorityreserve});

}

for my $affirmative (qw(scoreplus majorityquota minorityreserve)){
    for my $student (0..$student_number-1){
        for(my $k=0; $k < $loop_number; ++$k){
            if($table{$k}{benchmark}{$student}{race}==0){

                $result{$k}{$affirmative}{minoritybetter}++ if $table{$k}{benchmark}{$student}{schoolpreference} > $table{$k}{$affirmative}{$student}{schoolpreference};
                $result{$k}{$affirmative}{minorityworse}++ if  $table{$k}{benchmark}{$student}{schoolpreference} < $table{$k}{$affirmative}{$student}{schoolpreference};}
            if($table{$k}{benchmark}{$student}{race}==1){

                $result{$k}{$affirmative}{majoritybetter}++ if $table{$k}{benchmark}{$student}{schoolpreference} > $table{$k}{$affirmative}{$student}{schoolpreference};
                $result{$k}{$affirmative}{majorityworse}++ if  $table{$k}{benchmark}{$student}{schoolpreference} < $table{$k}{$affirmative}{$student}{schoolpreference};}
        }
    }
}
$minoritynum = grep {$table{0}{benchmark}{$_}{race} == 0} 0..$student_number-1;
$majoritynum = grep {$table{0}{benchmark}{$_}{race} == 1} 0..$student_number-1;
@affirmatives = qw(scoreplus majorityquota minorityreserve);
@welfares = qw(minoritybetter minorityworse majoritybetter majorityworse);
print "        minoritybetter minorityworse majoritybetter majorityworse\n";
for(my $i=0;$i < @affirmatives; $i++){
    for(my $j=0;$j < @welfares; $j++){
        for(my $k=0; $k < $loop_number; $k++){
            $totalnum{$affirmatives[$i]}{$welfares[$j]} += $result{$k}{$affirmatives[$i]}{$welfares[$j]};
        }
    }
}
for(my $i=0;$i < @affirmatives; $i++){
    print " $affirmatives[$i] ";
    for(my $j=0;$j < @welfares; $j++){
        $averagenum{$affirmatives[$i]}{$welfares[$j]} = $totalnum{$affirmatives[$i]}{$welfares[$j]}/$loop_number;
        print " $averagenum{$affirmatives[$i]}{$welfares[$j]}/$minoritynum " if $j <= 1;
        print " $averagenum{$affirmatives[$i]}{$welfares[$j]}/$majoritynum " if $j > 1;
        print "\n" if $j == @welfares-1;

    }
}

=i$workbook = Excel::Writer::XLSX->new("result".".xlsx");
$format = $workbook->add_format();
$format->set_bold();
$format->set_color('cyan');
$format->set_align('center');
$worksheet = $workbook->add_worksheet();

@affirmatives = qw(scoreplus majorityquota minorityreserve);
@welfares = qw(minoritybetter minorityworse majoritybetter majorityworse);
for(my $i=0;$i < @affirmatives; $i++){
    $worksheet->write($i+1,0,$affirmatives[$i],$format);
    for(my $j=0;$j < @welfares; $j++){
        $worksheet->write(0,$j+1,$welfares[$j],$format);
        $worksheet->write($i+1,$j+1,$result{$affirmatives[$i]}{$welfares[$j]}/$minoritynum,$format) if $j <= 1;
        $worksheet->write($i+1,$j+1,$result{$affirmatives[$i]}{$welfares[$j]}/$majoritynum,$format) if $j > 1;
}
}
=cut
