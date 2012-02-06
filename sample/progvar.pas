program owned;

var 	A, B, C : INTEGER;

BEGIN
	A := 2;
	B := 4;

	IF A = 2 THEN A := 1 ELSE B := 1;
	IF A < 2 THEN A := 1 ELSE B := 1;
	IF A > 2 THEN A := 1 ELSE B := 1;
	IF A >= 2 THEN A := 1 ELSE B := 1;
	IF A <= 2 THEN A := 1 ELSE B := 1;
	IF A <> 2 THEN A := 1 ELSE B := 1;
END.
