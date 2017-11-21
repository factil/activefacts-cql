schema VTP;

each Name is written as a String (
    27,
    42,
    accepts Encoding as String restricted to {'ascii', 'utf8', 'latin1'}
);

each Company Name is written as a Name(Encoding: 'ascii');
each Personal Name is written as a Name(restricts Encoding to {'latin1', 'utf8'});
each Given Name is written as a Personal Name(with Encoding as 'utf8');
each Family Name is written as a Personal Name(with Encoding as 'latin1');
