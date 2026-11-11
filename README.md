# Guerra Fria: Mundo Aberto (1983)

Jogo de tanques em mundo aberto para celular Android, ambientado na Europa Central durante a Guerra Fria.
Cenário fictício ("e se a guerra esquentasse?") inspirado na geografia e nos exércitos reais da época.

## Baixar o APK

Cada push gera um APK automaticamente pelo GitHub Actions:

1. Abra a aba **Releases** do repositório no celular.
2. Baixe o arquivo `GuerraFria-v1.0.X.apk` mais recente.
3. Instale (o Android vai pedir para permitir "instalar apps desconhecidos").

Também dá para jogar no navegador abrindo `web/index.html`.

## Nações jogáveis

| Nação | Lado | Tanque | Blindado | Helicóptero | Base inicial |
|---|---|---|---|---|---|
| União Soviética (URSS) | Pacto de Varsóvia | T-72 | BMP-1 | Mi-24 Hind | Wünsdorf (GSFG) |
| Polônia (PRL) | Pacto de Varsóvia | T-55A | OT-64 SKOT | Mi-2 | Szczecin |
| Alemanha Oriental (RDA) | Pacto de Varsóvia | T-72M | BTR-70 | Mi-8 | Berlim Oriental |
| Alemanha Ocidental (RFA) | OTAN | Leopard 1 | Marder | Bo 105 | Hannover |
| OTAN (forças dos EUA) | OTAN | M1 Abrams | M113 | AH-64 Apache | Base de Fulda |

## O mundo

- Mapa contínuo de cerca de 9.600 × 6.000 metros: da Renânia até Moscou e Kiev.
- 27 cidades capturáveis: Bonn, Hamburgo, Frankfurt, Munique, Berlim Ocidental e Oriental, Leipzig, Dresden, Rostock,
  Varsóvia, Gdańsk, Cracóvia, Poznań, Wrocław, Szczecin, Kaliningrado, Minsk, Kiev, Moscou e outras.
- **Cortina de Ferro** (cerca + faixa da morte) entre as duas Alemanhas, com postos de controle nas estradas.
- **Muro de Berlim** em volta de Berlim Ocidental, com Checkpoint Charlie na estrada entre as duas Berlins.
- Rios Reno, Elba, Oder, Vístula e Dnieper, Mar Báltico, florestas e estradas. O terreno muda a velocidade:
  estrada é mais rápida, floresta e rio são mais lentos, e a cerca atrasa muito.

## Como jogar

- **Joystick** (lado esquerdo da tela): move o tanque.
- **FOGO**: canhão. A torre mira sozinha no inimigo mais próximo.
- **MÍSSIL**: míssil antitanque guiado, com recarga.
- **Minimapa**: toque para abrir o mapa da Europa.
- **QUARTEL**: aparece quando você está numa cidade aliada sem inimigos por perto. Serve para reparar e comprar
  melhorias (blindagem, canhão, motor, mísseis).
- O botão **Voltar** do Android pausa o jogo. A campanha é salva automaticamente.

Para capturar uma cidade, elimine a guarnição e fique dentro do círculo. As missões são geradas o tempo todo:
capturar cidades, destruir comboios, defender cidades aliadas e recuperar documentos de espiões.
Vence o lado que dominar as 27 cidades.

Teclado (navegador): `WASD`/setas, `Espaço` = fogo, `E` = míssil, `M` = mapa, `B` = quartel, `Esc` = pausa.

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
web/index.html        o jogo inteiro (HTML5 Canvas + JavaScript, sem dependências)
web/icon.png          ícone
android/              app Android (WebView em tela cheia, horizontal) que empacota web/ como assets
.github/workflows/    compila o APK e publica no Releases
```

Para compilar localmente, use o Android SDK e rode `gradle assembleRelease` dentro de `android/`.
