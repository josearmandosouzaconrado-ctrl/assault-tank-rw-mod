# Mares de Fortuna (Godot 4)

Jogo de piratas em **mundo aberto** para celular Android (e computador), feito na engine **Godot 4.3**.
Mar do Caribe, 1705, durante a Guerra de Sucessão Espanhola: seja **pirata** ou oficial de uma das marinhas da época.

Tudo é gerado por código, sem nenhum arquivo de arte: ondas do oceano, céu, ilhas, cidades, navios, bandeiras, efeitos sonoros e a música.

## Baixar o APK

APK pronto: [`apk/MaresDeFortuna-v1.1.apk`](../apk/MaresDeFortuna-v1.1.apk) (Android 7 ou superior).

Cada push na pasta `piratas-godot/` gera um APK pelo GitHub Actions (workflow *Mares de Fortuna (Godot) - APK*):

1. Abra a aba **Releases** do repositório no celular.
2. Baixe o arquivo `MaresDeFortuna-v1.0.X.apk` mais recente.
3. Instale (o Android pede para permitir "instalar apps desconhecidos").

Cada versão é assinada com uma chave nova. Se o Android recusar a atualização, desinstale a versão anterior antes.

## Carreiras

| Carreira | Começo | Aliados | Inimigos |
|---|---|---|---|
| Pirata (Irmandade da Costa) | Saveiro em Nassau | outros piratas | todas as nações |
| Marinha Real Britânica | Brigue em Port Royal | Holanda, Portugal | Espanha, França, piratas |
| Armada Espanhola | Escuna em Havana | França | Grã-Bretanha, Holanda, Portugal, piratas |
| Marine Royale (França) | Escuna em Petit-Goâve | Espanha | Grã-Bretanha, Holanda, Portugal, piratas |
| Marinha Holandesa | Escuna em Sint Eustatius | Grã-Bretanha, Portugal | Espanha, França, piratas |
| Armada Portuguesa | Escuna em Olinda | Grã-Bretanha, Holanda | Espanha, França, piratas |

Você pode mudar de lado durante o jogo: desertar e virar pirata, comprar a anistia de um governador ou se alistar em outra marinha.
Na marinha você sobe de posto (Aspirante → Almirante), recebe soldo e a Coroa lhe entrega navios maiores.
Como pirata, sua infâmia cresce (Marujo Rebelde → Rei dos Piratas) e caçadores de recompensa passam a persegui-lo.

## O que dá para fazer

- **Navegar** num arquipélago de 16 × 16 km com 15 portos e mais de 50 ilhas. O vento muda, e a velocidade depende do ângulo do navio em relação a ele.
- **Combater** com bordadas. Há três munições: bala redonda (casco), bala corrente (velas) e metralha (tripulação).
- **Abordar** navios avariados: saquear, afundar ou **tomar o navio** para você.
- **Silenciar fortes e invadir cidades**. O porto passa a ser da sua nação, ou da Irmandade se você for pirata.
- **Comerciar** 8 mercadorias, cada porto com produção e procura próprias.
- **Missões**: caçar piratas, afundar inimigos, saquear mercantes, fazer entregas e conquistar portos.
- **Tesouros**: compre um mapa na taverna, desembarque na ilha, ande até o X e cave.
- **Bandeira falsa**: navios dessa nação não o reconhecem até você disparar.
- **Estaleiro**: 6 navios (Saveiro, Escuna, Brigue, Fragata, Galeão e Nau de Linha) e 4 melhorias.
- Ciclo de **dia e noite**, **tempestades** com chuva e relâmpagos, e navios de IA de todas as nações lutando entre si.
- Salvamento automático.

## Controles

Celular (horizontal):
- **Joystick** (canto inferior esquerdo): esquerda/direita vira o navio (ele tem peso e vira aos poucos); empurre para cima para soltar mais vela e para baixo para recolher.
- **Velas** (barra à direita): também dá para tocar direto em recolhidas, 1/3, 2/3 ou todas.
- A câmera fica atrás do navio e volta sozinha para trás dele depois que você para de girá-la.
- **BOMBORDO / ESTIBORDO**: dispara o costado da esquerda ou da direita. O anel mostra a recarga, e a mira ajuda a acertar o alvo mais próximo daquele lado.
- Arraste em qualquer outro lugar da tela para girar a câmera.
- **CÂMERA** alterna entre terceira pessoa e o timão em primeira pessoa. **LUNETA** dá zoom. **MUNIÇÃO** troca o tipo de bala. **BANDEIRA** iça uma bandeira falsa.
- O botão verde no centro aparece quando há uma ação: Atracar, Abordar, Invadir, Desembarcar, Cavar ou Voltar ao navio.
- A pé: joystick à esquerda e arrastar para olhar.

Computador: `A/D` leme, `W/S` velas, `Q/E` canhões, `R` munição, `C` câmera, `Z` luneta, `F` ação, `M` mapa, `Esc` pausa. Arraste com o mouse para olhar e use a roda para o zoom.

## Abrir no editor

1. Instale o Godot **4.3** (versão padrão, não a .NET).
2. *Importar* e escolha `piratas-godot/project.godot`.
3. Aperte F5.

O jogo usa o renderizador **Compatibility** (OpenGL ES 3), que funciona em quase todos os celulares Android.
No menu **Opções** dá para escolher a qualidade gráfica (baixa, média ou alta).

## Estrutura

```
project.godot           configuração (paisagem, renderizador Compatibility)
export_presets.cfg      exportação Android (APK arm64 + armv7)
scenes/main.tscn        cena inicial
scripts/game.gd         estado global: nações, navios, mercadorias, portos, carreira, save
scripts/world.gd        mundo: ilhas, céu, dia/noite, clima, tráfego de navios, fortes, regras
scripts/ship.gd         física de vela, flutuação, canhões, dano, naufrágio e IA dos capitães
scripts/ship_builder.gd modelo 3D procedural dos navios
scripts/island.gd       relevo, vegetação e cidades portuárias
scripts/ocean.gd        malha do oceano e ondas (as mesmas do shader, para a flutuação)
scripts/player.gd       câmeras (3ª pessoa, timão, luneta) e o modo a pé
scripts/hud.gd          interface de toque (multitoque), bússola, minimapa
scripts/port_ui.gd      mercado, estaleiro, taverna, missões e governo
scripts/map_ui.gd       mapa do arquipélago
scripts/menu_ui.gd      menu, escolha de carreira, opções e pausa
scripts/audio.gd        efeitos sonoros e música sintetizados
shaders/                oceano, céu, velas, bandeiras, madeira e terreno
```

## Tema musical

"Mares de Fortuna", melodia original em Ré menor, tocada pelo próprio jogo:

```abc
X:1
T:Mares de Fortuna
M:6/8
L:1/8
Q:3/8=105
K:Dm
A2d d2e | f2e d2c | A2G F2G | A6 |
A2d d2e | f2g a2f | e2c d2e | d6 |
f2f e2d | c2A c3 | B2A G2B | A6 |
d2c B2A | G2F G2A | E2F G2^c | d6 |]
```
