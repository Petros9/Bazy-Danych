select * from OSOBY

select * from wycieczki

select * from REZERWACJE


--1.a/
CREATE VIEW RezerwacjeWszystkie
 AS
    SELECT
        w.ID_WYCIECZKI,
        w.NAZWA,
        w.KRAJ,
        w.DATA,
        o.IMIE,
        o.NAZWISKO,
        r.STATUS
    FROM WYCIECZKI w
    JOIN REZERWACJE r ON w.ID_WYCIECZKI = r.ID_WYCIECZKI
    JOIN OSOBY o ON r.ID_OSOBY = o.ID_OSOBY;

select * from REZERWACJEWSZYSTKIE
--1.b/
CREATE VIEW RezerwacjePotwierdzone
    AS
        SELECT *
        FROM REZERWACJEWSZYSTKIE r
        WHERE r.STATUS = 'P'

select * from REZERWACJEPOTWIERDZONE
--1.c/
c) RezerwacjeWPrzyszlosci (kraj,data, nazwa_wycieczki, imie, nazwisko,status_rezerwacji)
CREATE View RezerwacjeWPrzyszlosci
    AS
        SELECT *
        FROM REZERWACJEWSZYSTKIE
        WHERE rezerwacjewszystkie.DATA > sysdate
--1.d/
d) WycieczkiMiejsca(kraj,data, nazwa_wycieczki,liczba_miejsc, liczba_wolnych_miejsc)
CREATE View WycieczkiMiejsca
    AS
        SELECT
               w.Kraj,
               w.data,
               w.nazwa,
               w.LICZBA_MIEJSC,
               w.LICZBA_MIEJSC - count(r.NR_REZERWACJI) as wolne_miejsca
        FROM WYCIECZKI w
        JOIN REZERWACJE r on w.ID_WYCIECZKI = r.ID_WYCIECZKI
        JOIN OSOBY o on r.ID_OSOBY = o.ID_OSOBY
        GROUP BY w.Kraj, w.data, w.nazwa, w.LICZBA_MIEJSC

--1.e/
e) WycieczkiDostepne(kraj,data, nazwa_wycieczki,liczba_miejsc, liczba_wolnych_miejsc)
CREATE View WycieczkiDostepne
    AS
        SELECT * FROM WycieczkiMiejsca
        WHERE wolne_miejsca>0
        and data > sysdate

