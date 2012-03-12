program sample6;

var
	a,b,c,d,e,f,g,h  :  integer;
	fiboarr : array [1..10] of integer;

function fibo(no: integer) : integer;
var fn1, fn2, temp, i : integer;
begin
	if no = 1 then fibo := 0
	else if no = 2 then fibo := 1
	else
	begin
		fn1 := 0;
		fn2 := 1;
		for i := 3 to no do
		begin
			temp := fn2;
			fn2 := fn1 + fn2;
			fn1 := temp;
		end;
		fibo := fn2;
	end;
end;

begin
	for a := 1 to 10 do
	begin
		fiboarr[a] := fibo(a);
	end;

	for a := 1 to 10 do
		writeln('fiboarr[', a, '] = ', fiboarr[a]);
end.
