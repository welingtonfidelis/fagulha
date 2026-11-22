# Créditos

## Sons

Os sons do jogo são montados por `tools/montar_sons.py` a partir das gravações abaixo, todas baixadas do
[OpenGameArt](https://opengameart.org) em 2026-11-15. Foram cortadas, misturadas, niveladas e fechadas em laço.

### Com crédito obrigatório (CC-BY)

| Obra | Autor | Licença | Onde entra |
|---|---|---|---|
| [Ambient Mountain, River, Wind and Forest and Waterfall](https://opengameart.org/content/ambient-mountain-river-wind-and-forest-and-waterfall) (do jogo Yo Frankie!) | Blender Foundation | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | o rio do vale |
| [Nature Sounds Pack](https://opengameart.org/content/nature-sounds-pack) | Antoine Goumain (Antoinemax) | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | folhagem, capim das pisadas e dos pousos |
| [Stream Sounds](https://opengameart.org/content/stream-sounds) | kurt | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | riacho e cachoeira |
| [Wind Loop](https://opengameart.org/content/wind-loop) | AntumDeluge, a partir de uma gravação de InspectorJ | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | vento do voo |
| [Jet Engine Takeoff](https://opengameart.org/content/jet-engine-takeoff) | dklon | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | decolagem |

### De domínio público (CC0), com agradecimento

| Obra | Autor | Onde entra |
|---|---|---|
| [Forest Ambience](https://opengameart.org/content/forest-ambience) | TinyWorlds | fundo da mata |
| [Ambient Bird Sounds](https://opengameart.org/content/ambient-bird-sounds) | isaiah658 | pássaros da mata de dia |
| [Crickets Ambient Noise](https://opengameart.org/content/crickets-ambient-noise-loopable) | Wolfgang_ | grilos da noite |
| [Rain (loopable)](https://opengameart.org/content/rain-loopable) | Ylmir | chuva |
| [Rain + Long Thunder](https://opengameart.org/content/rain-long-thunder) | WuxiaScrub | trovão longo |
| [Loopable Dungeon Ambience](https://opengameart.org/content/loopable-dungeon-ambience) | JaggedStone | cavernas |
| [Sci-Fi Sounds](https://opengameart.org/content/sci-fi-sounds) | Kenney (kenney.nl) | propulsores, tiros, impactos, Zangão e Sentinela |
| [Rocket Engine](https://opengameart.org/content/rocket-engine) | theMinesAreShakin | ronco do motor e da arrancada |
| [Metal footsteps on concrete](https://opengameart.org/content/metal-footsteps-on-concrete) | Thimras | pisadas do robô |
| [Metal Impact Sounds](https://opengameart.org/content/metal-impact-sounds) | BMacZero | pousos, golpe no chão, pisada do Sentinela |
| [Machine shutting down](https://opengameart.org/content/machine-shutting-down) | Cough-E | motor apagando e máquinas desligando |
| [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2) | rubberduck | trovão curto, sopros de ar, pedra, motor do Carrapato |

Os três avisos (alarme de calor, marcador e religar) são sintetizados por `tools/gerar_sons.py`.

Os sons de debaixo d'água (o ronco contínuo `agua_fundo_loop.wav`, as bolhas `bolhas_1` a `bolhas_4.wav` e o
splash da entrada `mergulho.wav`) são do próprio projeto, feitos por síntese em `tools/sons_agua.py` (2026-11-22),
sem gravação de terceiros.

## Modelos

Parte das árvores, as plantas de chão, as flores, os cogumelos, as moitas e as pedras soltas vêm de dois pacotes de
[Quaternius](https://quaternius.com), em domínio público (CC0), com agradecimento: *Textured Stylized Trees* e
*Stylized Nature MegaKit*. Foram convertidos por `tools/vale/pacotes.py` e ganharam a luz em faixas do vale.

Do *Stylized Nature MegaKit* (versão Standard) vêm também o capim em tufos, as árvores de folha larga, os pinheiros,
as árvores secas e de tronco torto, as pétalas, os seixos da beira d'água, convertidos por
`tools/vale/pacotes_mata.py`.


Os peixes do mar, dos rios e das lagoas são do *Cute Fish Pack* (fevereiro de 2020), de
[Quaternius](https://quaternius.com), em domínio público (CC0), com agradecimento.

Os cervos, os veados de galhada, as raposas e os lobos são do *Ultimate Animated Animals*, também de
[Quaternius](https://quaternius.com) e em domínio público (CC0), com as animações do pacote.

Os mechas do pacote *Mech_00* (jimmys7777), que não podiam ser redistribuídos, **saíram do jogo em 2026-11-20**:
os inimigos, os robôs caídos da Fundição e os gigantes passaram a ser modelos do próprio projeto. Os arquivos
continuam no histórico antigo do git (ver o fim deste arquivo).

## Base do robô

- **Sci-Fi Essentials Kit** e **Modular SciFi MegaKit**, de Quaternius (https://quaternius.com), CC0 1.0. Peças do hangar, caixas, antena e o drone colega (`assets/vale/base/`).
- **Faísca**, o robô da Ilha Cafuné (jogo do mesmo autor), em `assets/faisca/faisca.scn`.

## Robôs inimigos e gigantes

A Lata, o Guarda, o Barril e os chefes (o Colosso, a Lâmina e o Artilheiro), em `assets/vale/inimigos/`
(`lata.glb`, `guarda.glb`, `barril.glb`, `colosso.glb`, `lamina.glb`, `artilheiro.glb`), são do próprio projeto,
modelados por script no Blender (`tools/vale/inimigos.py`).

Os oito robôs inimigos de agora (Sentinela, Espadachim, Couraça, Batedor e Artilheiro; os chefes Capataz,
Canhoneiro e Guardião), em `assets/vale/robos_inimigos/`, são o robô do jogador com outras peças e outra
pintura, também do próprio projeto (`tools/vale/robo_v2.py` com `VARIANTE=<nome>`).

Os gigantes de obra do Sono dos Gigantes (a Escavadeira, o Guindaste e o Bate-estaca, em
`assets/vale/gigantes/`) também são do próprio projeto (`tools/vale/gigantes.py`).

## O robô do jogador

Os três robôs jogáveis (`assets/vale/robo_v1.glb`, `robo_v2.glb` e `robo_v3.glb`) são do próprio projeto,
modelados por script no Blender (`tools/vale/robo.py` e `tools/vale/robo_v2.py`).

O robô provisório dos primeiros dias (gerado no Tripo, com esqueleto e animações do Mixamo) **saiu do jogo e do
repositório em 2026-11-20**: os termos do Tripo para aquele modelo não estavam conferidos e o material do Mixamo
(Adobe) não pode ser redistribuído solto. Ele continua no histórico antigo do git (ver o fim deste arquivo).

## Factory Kit (Kenney)

Máquinas, esteiras, braços de robô, tubos, guindastes, engrenagens e telas do galpão da Fundição
(`assets/vale/fundicao/`). Factory Kit 3.0, de Kenney (www.kenney.nl), licença Creative Commons Zero (CC0).
Baixado de https://kenney.nl/assets/factory-kit em 2026-11-17.

## Efeitos da Fundição (Kenney)

- Partículas de explosão, clarão e laser: Kenney Particle Pack (www.kenney.nl), CC0 (`assets/fx/kenney/`).

## Imagens dos botões (Kenney)

As imagens de botão do controle, do teclado e do mouse (`assets/ui/botoes/`, 46 arquivos; o touchpad e o M entraram em 2026-11-20) vêm do Input Prompts
1.5a, de Kenney (www.kenney.nl), licença Creative Commons Zero (CC0). Baixado de
https://kenney.nl/assets/input-prompts em 2026-11-19.

## Texturas de ferrugem (Poly Haven)

- **Rusty Metal 02** e **Rust Coarse 01**, de Poly Haven (https://polyhaven.com), CC0
  (`assets/vale/ferrugem/`, em 1024 px). Usadas na ferrugem da base e da Fundição.

## A ave grande (Quaternius)

A águia do ninho (`assets/vale/aguia/aguia.glb`) é do "Animal Pack Vol.2", de Quaternius, licença Creative Commons
Zero (CC0). Baixado de https://opengameart.org/content/animated-animales-low-poly em 2026-11-19 e convertido
de FBX para glb no Blender. As cores são repostas no jogo (`NinhoAve.CORES_AVE`): na conversão vieram todas cinza.

## Morcegos (Danimal)

Os morcegos do Sumidouro (`assets/vale/morcego/morcego.glb`) são o "Vampire Bat (animated)", de Danimal, licença
Creative Commons Zero (CC0). Baixado de https://opengameart.org/content/vampire-bat-animated em 2026-11-20 e
exportado do `.blend` para glb no Blender. As texturas do pacote vão ao lado, reduzidas (`morcego_pelo.jpg`, `morcego_partes.jpg`).

## Pássaros pequenos (vk e FacadeGaikan)

Os pássaros do vale (`assets/vale/passaro.glb`) partem da "bird basemesh", de vk e FacadeGaikan, licença Creative
Commons Zero (CC0). Baixada de https://opengameart.org/content/bird-basemesh em 2026-11-20. O
`tools/vale/passaro_base.py` pinta a ave, separa as asas e acrescenta os olhos.

## Móveis da base (KayKit)

O sofá, a poltrona, o tapete, as mesas, a luminária, os quadros, os cactos e os enfeites da bancada
(`assets/vale/moveis/`) são do "KayKit Furniture Bits 1.0", de Kay Lousberg (www.kaylousberg.com), licença
Creative Commons Zero (CC0).

## Acampamentos de máquinas (KayKit e Quaternius)

As peças dos três acampamentos (`assets/vale/acampamentos/`, copiadas em 2026-11-22 da coleção local em
`bibliotecas/`, sem baixar nada):

- de Kay Lousberg (www.kaylousberg.com), licença Creative Commons Zero (CC0), com a textura de cada pacote:
  **KayKit Space Base Bits 1.0** (cata-vento, placa de sol, caixa-d'água), **KayKit Resource Bits 1.0** (tambores,
  estrados, caixotes, miúdos de ferro), **KayKit Block Bits 1.0** (armação de ferro da torre), **KayKit RPG Tools
  Bits 1.0** (balde, martelo, serrote, pá, malho, caixa de ferramentas) e **KayKit Halloween Bits 1.0** (lanternas);
- do **Modular SciFi MegaKit** e do **Sci-Fi Essentials Kit**, de Quaternius (https://quaternius.com), CC0 1.0:
  batente de porta, grade de ventilação, ventilador, holofote de chão, caixote, pilar, armário, bancada, estante e
  tambor fechado (os mesmos kits da base, peças que ainda não estavam no projeto).

O resto (chapas onduladas, lonas, contêineres, vigas, cabos, bandeirolas, baterias, o chão batido e o miolo dos montes
de sucata) é feito por código em `scripts/vale/acampamentos.gd`.

## O Vilarejo (OpenGameArt)

O vilarejo da terra nova (`assets/vale/vilarejo/`) é feito por código em `tools/arte/vilarejo_vila1.py`, menos três
peças baixadas do [OpenGameArt](https://opengameart.org) em 2026-11-22.

### Com crédito obrigatório (CC-BY)

| Obra | Autor | Licença | Onde entra |
|---|---|---|---|
| [Path to the house, road, way, route, driveway](https://opengameart.org/content/path-to-the-house-road-way-route-driveway) | twochch | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | a ruela de pedra com a mureta, até a escola (`ruela_pedra.glb`) |
| Paving square bricks (uma das texturas que vêm com o calçamento acima) | Keith333 | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | a pedra da mesma ruela |

### De domínio público (CC0), com agradecimento

| Obra | Autor | Onde entra |
|---|---|---|
| [Old fence](https://opengameart.org/content/old-fence) | carlosjorgereis | a cerca de madeira, repintada e assada com as casas |
| [Old metal fence](https://opengameart.org/content/old-metal-fence) | Paul Wortmann | a grade de ferro da escola, repintada |
| Mud, calçada portuguesa, stones, rock textures (as outras texturas do calçamento) | EmoPreben, Demetrius, Tont, GrEmlin | a pedra da ruela |

## Beehave (árvores de comportamento)

A cabeça das máquinas usa a Beehave 2.9.3, de bitbrain (https://github.com/bitbrain/beehave), licença MIT
(`addons/beehave/`, com a licença em `addons/beehave/LICENSE`).

## O repositório é público (2026-11-20)

Tudo o que está no jogo é CC0, CC-BY (sons, com o crédito na tabela do começo), MIT (Beehave) ou do próprio
autor. O que é do projeto está sob a licença MIT (`LICENSE`).

Para abrir, o histórico do git foi reescrito sem as três coisas que não podiam ser redistribuídas: os mechas
*Mech_00* (`assets/vale/mech00/`), o robô provisório gerado no Tripo com esqueleto do Mixamo (`assets/armadura/`)
e a cópia dele em `vendor/robot-test-v1.glb`. Por isso os commits têm identificadores novos: os que a
documentação cita de antes dessa data já não existem.

Os sons CC-BY pedem o crédito junto do jogo: o `CREDITOS.md` vai ao lado da build.
