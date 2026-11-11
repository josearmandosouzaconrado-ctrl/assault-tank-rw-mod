# Guerra Fria 3D: Mundo Aberto (1983)

> **Novo:** este repositório também traz **Mares de Fortuna**, um jogo de piratas em mundo aberto feito em **Godot 4**.
> Você pode ser pirata ou servir a uma das marinhas da época. Veja [`piratas-godot/README.md`](piratas-godot/README.md).
> O APK sai na aba Releases com o nome `MaresDeFortuna-v1.0.X.apk`.

Jogo de tiro **3D em primeira pessoa** em mundo aberto para celular Android, ambientado na Europa Central durante a Guerra Fria.
Você anda a pé como soldado, com fuzil e lança-foguetes, e pode entrar em tanques e blindados (também em primeira pessoa).
Cenário fictício ("e se a guerra esquentasse?") inspirado na geografia e nos exércitos reais da época.

## Baixar o APK

Cada push gera um APK automaticamente pelo GitHub Actions:

1. Abra a aba **Releases** do repositório no celular.
2. Baixe o arquivo `GuerraFria-v1.0.X.apk` mais recente.
3. Instale (o Android vai pedir para permitir "instalar apps desconhecidos").

Também dá para jogar no navegador abrindo `web/index.html`.

## Nações jogáveis

| Nação | Lado | Fuzil | Lança-foguetes | Tanque | Blindado | Helicóptero | Base inicial |
|---|---|---|---|---|---|---|---|
| União Soviética (URSS) | Pacto de Varsóvia | AK-74 | RPG-7 | T-72 | BMP-1 | Mi-24 Hind | Wünsdorf (GSFG) |
| Polônia (PRL) | Pacto de Varsóvia | Kbk AKM | RPG-7 | T-55A | OT-64 SKOT | Mi-2 | Szczecin |
| Alemanha Oriental (RDA) | Pacto de Varsóvia | MPi-KM | RPG-7 | T-72M | BTR-70 | Mi-8 | Berlim Oriental |
| Alemanha Ocidental (RFA) | OTAN | G3 | Panzerfaust 44 | Leopard 1 | Marder | Bo 105 | Hannover |
| OTAN (forças dos EUA) | OTAN | M16A2 | M72 LAW | M1 Abrams | M113 | AH-64 Apache | Base de Fulda |

## O mundo

- Mundo 3D contínuo de 9,6 × 6 km, da Renânia até Moscou e Kiev, com relevo, florestas e rios. Ele é carregado em blocos conforme você anda.
- 27 cidades capturáveis: Bonn, Hamburgo, Frankfurt, Munique, Berlim Ocidental e Oriental, Leipzig, Dresden, Rostock,
  Varsóvia, Gdańsk, Cracóvia, Poznań, Wrocław, Szczecin, Kaliningrado, Minsk, Kiev, Moscou e outras.
- Cidades com prédios em 3D e a bandeira do dono atual na praça central.
- **Cortina de Ferro** entre as duas Alemanhas: cerca de arame, faixa da morte e torres de vigia, com postos de controle nas estradas.
- **Muro de Berlim** em 3D em volta de Berlim Ocidental, com passagens nas estradas (Checkpoint Charlie).
- Rios Reno, Elba, Oder, Vístula e Dnieper, Mar Báltico, florestas e estradas. O terreno muda a velocidade:
  estrada é mais rápida, floresta e rio são mais lentos, e a cerca atrasa muito.

## Como jogar

Celular:
- **Joystick** (lado esquerdo): andar. No tanque: acelerar, dar ré e virar.
- **Arrastar no lado direito**: olhar/mirar. Arrastar o botão **FOGO** também mira enquanto atira.
- **FOGO**: fuzil (pente de 30, recarrega sozinho). No tanque: canhão.
- **RPG**: lança-foguetes antitanque. No veículo: **METRALHADORA**.
- **MIRA**: zoom para tiros de longe.
- **ENTRAR / SAIR**: entra no tanque ou blindado aliado mais próximo. No começo há um tanque estacionado ao seu lado.
- **QUARTEL**: numa cidade aliada sem inimigos por perto. Serve para curar ou reparar, comprar foguetes, requisitar um tanque, fazer melhorias e usar o **transporte rápido** entre cidades aliadas.
- **Minimapa**: toque para abrir o mapa da Europa. O botão **Voltar** do Android pausa o jogo.

Computador: clique para capturar o mouse, `WASD` move, botão esquerdo atira, botão direito mira, `F` = RPG, `E` = entrar/sair, `R` = recarregar, `B` = quartel, `M` = mapa, `Esc` = pausa.

Para capturar uma cidade, elimine a guarnição e fique dentro dela até a barra encher. As missões são geradas o tempo todo:
capturar cidades, destruir comboios, defender cidades aliadas e recuperar documentos de espiões.
Vence o lado que dominar as 27 cidades. A campanha é salva automaticamente.

No menu, **Gráficos: rápido/bonito** troca a resolução e a distância de visão (use "rápido" em celulares mais simples).

## Música

Tema original "Cortina de Ferro", tocado pelo próprio jogo com Web Audio:

```abc
X:1
T:Cortina de Ferro
M:4/4
L:1/8
Q:1/4=96
K:Dm
D2 F2 A3 G | F2 E2 D4 | C2 E2 G3 F | E2 D2 ^C4 |
D2 F2 A3 c | d2 c2 A4 | B2 A2 G2 E2 | D8 |]
```

## Estrutura

```
web/index.html        menus e interface
web/game.js           o jogo 3D (mundo, unidades, IA, armas, missões)
web/lib/three.min.js  motor 3D Three.js r149 (licença MIT, embutido para funcionar offline)
web/icon.png          ícone
android/              app Android (WebView em tela cheia, horizontal) que empacota web/ como assets
.github/workflows/    compila o APK e publica no Releases
```

Para compilar localmente, use o Android SDK e rode `gradle assembleRelease` dentro de `android/`.
