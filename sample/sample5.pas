program sample5;
var A, B, C :  integer;
begin
   A:=1;
   B:=4;
   while (A < B) do
      begin
	 writeln(A);
	 A := A + 1;
      end;
   writeln(B);
end.
