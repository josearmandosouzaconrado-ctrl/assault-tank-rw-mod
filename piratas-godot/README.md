# Mares de Fortuna (Godot 4)

Jogo de piratas em **mundo aberto** para celular Android (e computador), feito na engine **Godot 4.3**.
Mar do Caribe, 1705, durante a Guerra de Sucessão Espanhola: seja **pirata** ou oficial de uma das marinhas da época.

O oceano, o céu, o relevo, os navios, as bandeiras, os sons e a música são gerados por código. As pessoas, o cavalo,
as casas, o forte, o cais e a vegetação usam modelos 3D gratuitos (CC0) da **Kenney** e da **Quaternius**
— veja `assets/CREDITOS.md`.

## Baixar o APK

APK pronto: [`apk/MaresDeFortuna-v1.8.apk`](../apk/MaresDeFortuna-v1.8.apk) (Android 7 ou superior).

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

- **Navegar** por um Caribe de 24 × 24 km com o contorno real das costas (dados do Natural Earth) e 19 portos nas posições históricas: Cuba, Hispaniola, Jamaica, Porto Rico, Bahamas, Pequenas Antilhas, Flórida e a costa dos EUA, Yucatán e México, e a costa da América do Sul. O vento muda, e a velocidade depende do ângulo do navio em relação a ele.
- **Viagem rápida**: no mapa, toque num porto amigo e em *Viagem rápida* (os dias passam conforme a distância).
- **Andar pelas cidades** (botão *Passear* no porto): moradores pelas ruas, guardas com a farda da nação, taverna, igreja e forte.
- **Cavalgar**: pegue um cavalo no estábulo e siga pelas estradas que ligam as cidades da mesma ilha ou do continente.
- **Exército**: contrate soldados na taverna. Eles lutam nas abordagens e invasões e seguem você em terra.
- **Bebidas e moral**: pague rodadas de rum para a tripulação (moral alta recarrega os canhões mais rápido e vence abordagens) ou beba você mesmo, e o mundo balança.
- **Romance**: em cada cidade há uma pessoa especial. Converse, dê presentes, convide para jantar e, com afeto máximo, peça em casamento.
- **Combater** como no Black Flag: bordadas pelos costados (três munições: redonda, corrente e metralha), **canhões de proa** com corrente que freia o inimigo, **morteiros** de longe (o círculo vermelho mostra onde as bombas caem; os inimigos grandes também usam), **segurar-se** para receber menos dano e **abalroar** (melhor com o esporão de ferro).
- **Abordagem em tempo real** (como em Black Flag): os navios ficam presos pelos ganchos e você luta no convés inimigo com o sabre, ao lado da sua tripulação. ESPADA golpeia em sequência, DEFENDER apara — se o inimigo atacar (marca vermelha sobre a cabeça) enquanto você apara, vem o contra-ataque — e PISTOLA dá um tiro a cada 6 s. Derrube todos para render o navio.
- **Personagens realistas**: modelos humanos com animações de verdade (andar, correr, sabre, aparar, morrer), roupas recortadas por região (casaca, colete, camisa, calção, meias, sapatos), cabelo com rabicho ou coque, e mosquete de pederneira detalhado (fecho, latão, vareta, bandoleira, baioneta).
- **Combate a pé**: o capitão anda em terceira pessoa com mosquete e sabre (botão SABRE). Em cidades inimigas (ou se você atirar numa cidade amiga) os guardas atacam; suas tropas atiram junto. Com o forte silenciado e todos os guardas derrubados, dá para **tomar a cidade** a pé.
- **Uniformes e roupas da época**: casacas compridas com vistas coloridas por nação (vermelho britânico, branco espanhol, cinza-esbranquiçado francês, azul holandês, verde português), talabarte e tricórnio; marujos de calções largos; mulheres de saia comprida, avental e touca. Os soldados seguram o mosquete como nos manuais de armas: ombro-armas, descansar e apontar.
- **Alfaiate e armeiro**: roupas, cor da casaca, chapéus (tricórnio, lenço, abas largas, bicórnio) e armas (mosquete comum, pistolas, mosquete de precisão).
- **Seu próprio reino**: com 2 cidades conquistadas e 15.000 moedas, funde um reino com nome e bandeira próprios; as cidades rendem impostos diários.
- **Guerras entre nações**: de tempos em tempos uma nação ataca um porto inimigo. Perto dele, você vê a batalha naval e pode ajudar a atacar ou a defender; os portos mudam de dono.
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
- **PROA**, **MORTEIRO** e **SEGURAR**: armas extras e defesa (o morteiro aparece depois de comprado no estaleiro).
- **Velas** (barra à direita): também dá para tocar direto em recolhidas, 1/3, 2/3 ou todas.
- A câmera fica atrás do navio e volta sozinha para trás dele depois que você para de girá-la.
- **BOMBORDO / ESTIBORDO**: dispara o costado da esquerda ou da direita. O anel mostra a recarga, e a mira ajuda a acertar o alvo mais próximo daquele lado.
- Arraste em qualquer outro lugar da tela para girar a câmera.
- **CÂMERA** alterna entre terceira pessoa e o timão em primeira pessoa. **LUNETA** dá zoom. **MUNIÇÃO** troca o tipo de bala. **BANDEIRA** iça uma bandeira falsa.
- O botão verde no centro aparece quando há uma ação: Atracar, Abordar, Invadir, Desembarcar, Cavar ou Voltar ao navio.
- A pé: joystick à esquerda e arrastar para olhar. O botão verde muda conforme o lugar: Conversar, Falar com..., Entrar na taverna, Montar no cavalo, Cavar ou Voltar ao navio.
- A cavalo: joystick para frente acelera, para os lados vira; a câmera fica atrás do cavalo.

Computador: `A/D` leme, `W/S` velas, `Q/E` canhões, `G` proa, `T` morteiro, `B` segurar, `X` mosquete/pistola, `J` sabre, `K` defender, `R` munição, `C` câmera, `Z` luneta, `F` ação, `M` mapa, `Esc` pausa. Arraste com o mouse para olhar e use a roda para o zoom.

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
scripts/island.gd       massas de terra (espinha de pontos) e relevo
scripts/terrain_tile.gd blocos de terreno de 800 m com dois níveis de detalhe e vegetação
scripts/port_site.gd    cidades portuárias, cais, forte, estradas
scripts/town_life.gd    moradores, guardas, pessoa especial e modelos de pessoa e cavalo
scripts/horse.gd        cavalo de montaria
scripts/wake.gd         esteira de espuma que segue o caminho do navio
scripts/ocean.gd        malha do oceano e ondas (as mesmas do shader, para a flutuação)
scripts/player.gd       câmeras (3ª pessoa, timão, luneta) e o modo a pé
scripts/hud.gd          interface de toque (multitoque), bússola, minimapa
scripts/port_ui.gd      mercado, estaleiro, taverna, missões e governo
scripts/map_ui.gd       mapa do arquipélago
scripts/menu_ui.gd      menu, escolha de carreira, opções e pausa
scripts/audio.gd        efeitos sonoros e música sintetizados
scripts/attire.gd       roupas da época presas aos ossos (casaca, vistas, talabarte, saia, calções)
scripts/musket_rig.gd   posições do mosquete com cinemática inversa nos braços
scripts/boarding.gd     abordagem em tempo real (sabre, aparar/contra-ataque, pistola)
scripts/attire.gd       roupas, cabelo, chapéus e sabre presos aos ossos
shaders/person.gdshader corpo dos personagens com as roupas da época
tools/preparar_humanos.py  reduz os modelos humanos para o celular
scripts/assets.gd       carrega os modelos 3D, animações e junta peças numa malha só
assets/                 modelos 3D CC0 (Kenney e Quaternius) — ver assets/CREDITOS.md
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
