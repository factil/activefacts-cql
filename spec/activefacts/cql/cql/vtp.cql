schema VTP;

each Name is written as a String (
    27,
    42,
    accepts Encoding as String restricted to {'ASCII'..'blarf', 'utf8', 'latin1', 1..4}
);

each Farnarkle Name is written as a Name(Encoding: 4);
each Company Name is written as a Name(Encoding: 'ASCII');
each Personal Name is written as a Name(restricts Encoding to {'latin1', 'utf8'});
each Given Name is written as a Personal Name(with Encoding as 'utf8');
each Family Name is written as a Personal Name(with Encoding as 'latin1');
