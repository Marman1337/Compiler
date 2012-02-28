program owned;

var 	A, B, go: INTEGER;

BEGIN
	A := 0-2;
	B := 0-4;
	go := B/A;
	writeln('-4/-2 is ', go);

	A := 0-3;
	B := 0-9;
	go := B/A;
	writeln('-9/-3 is ', go);

	A := 0-2;
	B := 4;
	go := B/A;
	writeln('4/-2 is ', go);

	A := 2;
	B := 0-4;
	go := B/A;
	writeln('-4/2 is ', go);

	A := 2;
	B := 0-16;
	go := B/A;
	writeln('-16/2 is ', go);
END.
