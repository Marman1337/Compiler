program owned;

var 	A, B, C, D : INTEGER;

BEGIN
	A := 1;
	B := 2;
	C := 3;
	D := 4;
	
	IF  A > 0  THEN B := 1 ELSE B := 2;
	

	IF (B = 1) THEN
	BEGIN
		C := 4;
		D := 5;
	END
	ELSE
	BEGIN
		C := 7;
		D := 8;
	END;

	B := 0;
	C := 0;

	FOR A := 1 TO 5 DO
	BEGIN
		B := B+A;
		C := C+A+A;
	END;
END.
