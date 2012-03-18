program alll;

var				(* global variables *)
	a,b,c,index :  integer;
	fiboarr : array [1..10] of integer;

function fibo(no: integer) : integer; (* function which returns n-th Fibonacci number *)
var fn1, fn2, temp, i : integer;
begin
	if no = 1 then fibo := 0
	else if no = 2 then fibo := 1
	else
	begin
		fn1 := 0;
		fn2 := 1;
		i := 3;
		while i <= no do
		begin
			i := i+1;
			temp := fn2;
			fn2 := fn1 + fn2;
			fn1 := temp;
		end;
		fibo := fn2;
	end;
end;

procedure fiboprint(n : integer);	(* procedure which prints n Fibonacci numbers *)
var f1, f2, tmp, j : integer;
begin
	if n >= 1 then writeln('Fibo 0: 0');
	if n >= 2 then writeln('Fibo 1: 1');
	if n >= 3 then
	begin
		f1 := 0;
		f2 := 1;
		j := 3;
		while j <= n do
		begin
			tmp := f2;
			f2 := f1 + f2;
			f1 := tmp;
			writeln('Fibo ', j, ': ', f2);
			j := j+1;
		end;
	end;
end;

begin
	write('Lets demonstrate arithmetic. Enter the first number: '); read(a);
	write('Good. Enter the second number: '); read(b);
	c := a+b;   writeln(a, ' + ', b, ' = ', c);
	c := a-b;   writeln(a, ' - ', b, ' = ', c);
	c := a*b;   writeln(a, ' * ', b, ' = ', c);
	c := a/b;   writeln(a, ' / ', b, ' = ', c);

	writeln('Fine, now, how many fibo numbers do you want print?: '); read(a); fiboprint(a);
	writeln('OK. Now try with another number: '); read(a); fiboprint(a);
	
	writeln('Done. Type any number to continue: '); read(a);

	writeln('Now lets populate the fiboarr[1..10] array');
	writeln('with fibonacci numbers using the fibo function');
	writeln('Generating fibonacci numbers...');
	for index := 1 to 10 do	fiboarr[index] := fibo(index); (* populate the array with Fibonacci numbers *)

	writeln('Done. Lets now print the entire array.'); writeln(' ');
	for index := 1 to 10 do	writeln('fiboarr[', index, '] = ', fiboarr[index]); (* print the contents of the array *)
end.