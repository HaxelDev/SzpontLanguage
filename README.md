# Szpont Language

> *"Nie znajdziecie kurwa tu takiego szponta, a tu macie"* – Igor Grabowski (cytuję bo kurwa trzeba)

Szpont to aktualnie **najlepszy polski język programowania** bo wreszcie możesz pisać programy jak człowiek, a nie jak węgierski znak diakrytyczny.
To język stworzony jako połączenie **Pythona** i **C++**.

# Co to jest Szpont?

Kurwa ile trzeba powtarzać że to jest  **język programowania** człowieku.
Piszesz klasy, funkcje, pętle, możesz nawet odpalić transpiler do Pythona. Interpreter też jest, bo nie zawsze chce się klepać w gcc.

# Szybki start

## 1. Napisz program, np. `hello.sz`:
```szpont
class Main {
  def main() {
    szpont print("Witaj Szponcie!");
  }
}
```
## 2. Odpal terminala:
```
szpont hello.sz
```
Ewentualnie możesz też:
```
szpont hello.sz --main TwojaKlasa
```
## (3.) Możesz też wygenerować jako kod Pythona:
```
szpont hello.sz --target python
python hello.py
```
A jak chcesz być wizjonerem, próbuj --target cpp (spoiler: na razie dostaniesz komunikat, że jeszcze nie jest dostępne).

# Dlaczego warto używać Szponta?

- Bo Igor Grabowski by tak chciał.
- Bo szpont print("japierdole stworzylem demona"); wygląda lepiej niż printf albo System.out.println.
- Bo można pisać jak w Pythonie, ale mieć klasy i typy jak w C++.
- Bo memiczna nazwa przyciągnie ludzi na Twoje repo.

# Inspiracja

Projekt inspirowany złotą myślą Igora Grabowskiego oraz frustracją wynikającą z nadmiaru nawiasów w C++ i wcięć w Pythonie.

<img src="https://media.discordapp.net/attachments/1133545182046986321/1410378807742828564/lv_0_20250827233730-ezgif.com-video-to-gif-converter.gif?ex=68b0cd1f&is=68af7b9f&hm=c20b21e5d3df1adcaea79d53d591089513679206229c750ccad4218c54f8b873&=" alt="Szpont">

# Licencja

Jeszcze nie ustalone, ale pewnie MIT, żeby każdy mógł sobie używać i dorzucać pierdolenia.
