program sample6;

var A, B, C :  integer;

function incr(X: integer):integer;
   begin
       incr := X + 1;
   end;

begin
   A:=1;
   B:=incr(A);
   writeln(B);
end.
