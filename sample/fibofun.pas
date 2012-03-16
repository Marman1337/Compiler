program fibofun;

var
	a,b :  integer;

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
	a := 1;
	while a > 0 do
	begin	
		writeln('Which fibo number do you want?');
		read(a);
		b := fibo(a);
		writeln('The ', a, 'th fibo number is: ', b);
	end;
end.
