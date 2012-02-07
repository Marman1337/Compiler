program owned;

var 	A, B, C, D : INTEGER;

BEGIN
	A := 2+3;
	B := 3;
	C := 4;
	IF A > B+C (* else should be execured, B = 1, A stays the same, A = 5 *) THEN A := 1 ELSE B := 1;
	D := B;
END.
