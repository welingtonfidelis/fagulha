# Relatório do game dev sênior: desempenho, arquitetura e controles

Faísca 2: Em Busca do Sossego, `main` em `a55938a` (2026-11-19). Mac M4 (10 núcleos, 16 GB), Godot 4.7.2, Metal, Forward+, janela de 1600 × 900.

Legenda usada no texto inteiro:

- **[medido]**: número que saiu de uma execução minha, descrita na seção "Como medi".
- **[lido]**: conclusão tirada da leitura do código, sem medição.
- **[estimativa]**: conta ou palpite meu, com a base dita ao lado.

## Resumo em 5 linhas

1. A mata é o quadro inteiro. Com toda a vegetação escondida, a vista da mata cai de 34 ms para 8 ms; as árvores de perto e as de meia distância (`_longe`) somam de 9 ms (base) a 23 ms (sobre a mata) **[medido]**.
2. O que pesa nas árvores são os pixels das placas de folha, empilhadas umas sobre as outras, e não os triângulos. Só desenhar as folhas de um lado (`cull_back`) já tira 6 ms na mata. Tirar o `discard` das cascas e pedras tira mais 1,8 ms **[medido]**.
3. Há 9 a 14 ms "baratos" nos efeitos de tela: SSAO (3 a 5 ms), MSAA 4x (5 a 6 ms contra desligado), desfoque de fundo (1,3 ms) e o mar que copia a tela (1,2 ms). Nenhum nível de qualidade mexe no SSAO, no desfoque nem no mar **[medido]**.
4. Os trancos vêm do processador. Refazer a colisão das árvores leva 20 a 28 ms, e isso acontece a cada 12 m andados ou voados. Criar um bloco de capim leva 8 a 10 ms, e nasce um bloco por quadro enquanto o robô anda **[medido]**. No Ryzen 5 5500 do PC deve pesar mais **[estimativa]**.
5. 60 fps na mata nesta arquitetura: no PC (3060 Ti), sim, com os cortes desta lista e a qualidade média ou alta. No Mac só com a baixa, ou trocando a mata de meia distância por impostores **[estimativa, contas no fim da seção de otimizações]**.

## Como medi

- **Ferramenta:** um script meu, fora do projeto (`scratchpad/dev/medir.gd`, carregado com `godot --path . -s medir.gd -- --vale-captura --perf --hora 15`). Ele abre a cena do jogo, tira a captura do jogo do caminho, desliga o vsync (`Engine.max_fps = 0`) e mede 90 quadros seguidos depois de 25 de aquecimento. O resultado é a mediana do tempo de quadro. A cada vista, desliga uma coisa por vez e mede de novo. As trocas de shader foram feitas só na memória: copiei o código, alterei e pus no material durante a execução. Nenhum arquivo do jogo mudou.
- **Pontos:** os mesmos do `--perf` do jogo: "mata fechada, no chão" (140, -600), "base, olhando o campo", "sobre a mata, a 60 m" e "campos do sul". Qualidade alta, a mesma das fotos.
- **Outros agentes:** antes de cada rodada, o script esperava não haver outro Godot com janela rodando, e um processo à parte anotava quem rodava junto. Durante todas as minhas rodadas válidas, havia uma bateria de testes sem janela (`--teste-vale`) rodando ao lado. Ela disputa o processador, não a placa.
- **Margem de erro:** sem outro Godot com janela, a mesma vista medida várias vezes variou de 34,3 a 35,6 ms na mata (cerca de ±2%), e o p90 ficou a menos de 1 ms da mediana. Por isso só trato como real uma diferença acima de 1 ms. Com outro Godot com janela rodando junto, a mesma vista pulava entre 34 e 60 ms (duas a três vezes de diferença). Descartei essas rodadas: a primeira saída do `--perf` do jogo e a primeira dos experimentos de shader.
- **Tempos de processador** (capim, colisão) foram medidos com a bateria de testes ocupando outros núcleos. Podem estar uns 10 a 30% acima do que dariam com o Mac livre **[estimativa]**.
- **Tempo de placa:** o `viewport_get_measured_render_time_gpu` volta 0 no Metal. Por isso o `--perf` do jogo mostra "placa 0,0", e a linha "script" dele inclui a espera pela placa. Todos os tempos abaixo são o quadro inteiro, medido no relógio.

## Tabela das medidas

Tempo de quadro em ms, mediana, qualidade alta **[medido]**. "Δ" é quanto o quadro cai quando aquilo é desligado: quanto maior, mais aquilo custa.

| Vista | Alta | Média | Baixa | Sem mata nenhuma |
|---|---|---|---|---|
| Mata fechada, no chão | 34,4 (29 qps) | 29,2 (34) | 24,1 (41) | 8,2 (121) |
| Base, olhando o campo | 33,6 (30) | 27,3 (37) | 21,6 (46) | 10,9 (91) |
| Sobre a mata, a 60 m | 39,1 (26) | 32,6 (31) | 26,9 (37) | 8,6 (116) |
| Campos do sul | 16,2 (62) | 14,0 (71) | 11,7 (85) | 8,0 (124) |

O custo de cada coisa (Δ em ms, sobre a alta):

| Desligado | Mata | Base | Sobre a mata | Campos do sul |
|---|---|---|---|---|
| Árvores de perto (até 190 m) | **9,1** | 3,6 | **13,9** | 0 |
| Árvores `_longe` (190 a 450 m) | **6,6** | **5,9** | **9,0** | 0 |
| Vultos (450 a 2.300 m) | 1,2 | 2,4 | 1,6 | 0,1 |
| Formas de sombra das árvores | 0,6 | 0,5 | 0,5 | 0 |
| Plantas do chão (97 mil peças) | 1,4 | 1,3 | 1,2 | 0,9 |
| Outros MultiMesh (paredões, arbustos) | 0,6 | 1,3 | 0,6 | 0,3 |
| Chão (250 malhas) | 0,4 | 0,5 | 0,5 | 0,9 |
| Água (mar, rios, lagoas) | 1,2 | 1,3 | 1,3 | 1,2 |
| Capim fixo da clareira | 0 | **5,2** | 0 | 0 |
| Capim vivo (o que nasce em volta) | 1,3 | 0,2 | 0,6 | **6,7** |
| Sombra do sol inteira | 2,6 | 2,9 | 2,3 | 1,3 |
| Sombra até 150 m em 2 faixas (em vez de 380 m em 4) | 0,9 | 0,9 | 1,0 | 0 |
| MSAA 4x → 2x | 2,9 | 3,1 | 3,4 | 1,5 |
| MSAA 4x → desligado | **5,4** | **6,3** | **6,3** | 3,2 |
| SSAO | **4,0** | 3,0 | **4,8** | 1,1 |
| Desfoque de fundo (DOF) | 1,3 | 1,3 | 1,2 | 1,3 |
| Brilho (glow) | 0,3 | 0,4 | 0,3 | 0,4 |
| Céu sem refazer o reflexo todo quadro | 0,8 | 0,4 | 0 | 0,3 |
| Resolução 3D a 50% | 13,9 | 10,3 | 16,4 | 4,9 |

Experimentos de shader, só na memória (Δ em ms; cada um medido duas vezes, sempre entre duas medidas do original):

| Mudança | Mata | Sobre a mata |
|---|---|---|
| Capim: sai cedo quando a touceira está encolhida e não calcula `inverse(MODEL_MATRIX)` | 0 | 0 |
| `vale_tex`: calcula o vento só depois de saber se a peça aparece | 0,5 | 0 |
| `vale_tex` sem nenhum `discard` nos materiais sem recorte (cascas, pedras, cogumelos, seixos) | **1,8** | **1,9** |
| Folhas com `cull_back` em vez de `cull_disabled` | **6,4** | **3,5** |
| Folhas sem a trama da troca por distância | 3,0 | −2,6 (piora) |
| Juntos: capim + opacos sem `discard` + folhas sem trama | **7,6** | **3,8** |

Processador, medido chamando as funções do jogo uma a uma:

| O quê | Tempo | Quando acontece |
|---|---|---|
| `Ilha.atualizar_colisao_arvores` (refaz até 900 formas) | **20 a 28 ms** | a cada 12 m que o robô anda ou voa |
| `CapimVivo._criar` (um bloco de 32 m) | **8 a 10 ms** | um bloco por quadro, enquanto faltar bloco perto do robô |
| `CapimVivo._criar_longe` (um bloco de 64 m) | 5 ms | um por quadro, quando o capim de perto está em dia |

Voo de teste: o robô é levado à mão em linha reta, com a câmera atrás. Na mata, 500 m a 25 m/s e 25 m de altura; nos campos do sul, 500 m a 12 m/s e 2,5 m de altura. Duas rodadas de cada; aqui vai a pior **[medido]**:

| Voo | Mediana | p99 | Pior | Quadros acima de 50 ms |
|---|---|---|---|---|
| Mata, tudo ligado | 40,0 ms | 64,9 | 78,9 | 12 (de ~500) |
| Mata, sem refazer a colisão das árvores | 38,4 | 48,2 | 67,9 | 5 |
| Mata, sem capim novo | 38,4 | 47,3 | 64,6 | 3 |
| Campos do sul, tudo ligado | 19,9 | 24,6 | 55,9 | 1 (de ~2.100) |

O mesmo voo com a placa aliviada (resolução 3D a 35%, sem MSAA nem SSAO, qualidade baixa), para simular uma placa forte e deixar o processador à mostra. Pior de duas rodadas **[medido]**:

| Voo, placa aliviada | Mediana | p99 | Pior |
|---|---|---|---|
| Mata, tudo ligado | 13,2 ms | **36,9** | 48,4 |
| Mata, sem refazer a colisão das árvores | 13,3 | **18,1** | 40,1 |
| Mata, sem capim novo | 13,2 | 39,7 | 45,3 |
| Campos do sul, tudo ligado | 13,3 | **23,7** | 70,9 |
| Campos do sul, sem capim novo | 13,3 | **16,0** | 23,3 |

Nessa condição, refazer a colisão das árvores põe o p99 da mata de 18 para 37 ms. São umas duas travadas de 25 a 35 ms por segundo de voo, 41 em 20 s. Nos campos, o capim novo põe o p99 de 16 para 24 ms, com pico de 71 ms.

No Mac os picos de processador ficam meio escondidos: enquanto a placa demora 38 ms por quadro, o processador tem tempo de sobra para os 20 a 28 ms da colisão. Mesmo assim, a colisão dobra os quadros acima de 50 ms e põe o p99 de 48 para 65 ms. Numa placa mais rápida que o processador, como a 3060 Ti com o Ryzen 5 5500, os picos aparecem inteiros.

Números da cena **[medido]**: 40.993 nós; 9.070 blocos de árvores de perto, 3.602 de `_longe`, 548 de vultos e 9.600 de formas de sombra; 5.276 blocos de plantas do chão com 97.005 peças, que somam 54,5 milhões de triângulos guardados (média de 560 por planta); 108 blocos de capim fixo com 75.434 tufos, 11,7 milhões de triângulos; 2,9 a 4,0 mil chamadas de desenho por quadro; 630 MB de vídeo e 1 GB de memória.

Abertura do jogo, com cache, medida com outros agentes rodando **[medido, com ruído]**: o primeiro quadro desenhado sai aos 10,5 s. O mundo fica pronto aos 6,6 s; o resto é montar os bichos, a vida na água (0,33 s) e compilar os shaders. Os passos mais caros: colisão dos paredões (1,9 s, mesmo com cache), `_mata_fora` (0,46 s), `_preparar_rio` (0,73 s), `Fundicao.montar` (0,59 s) e `Marcos.montar` (0,45 s).

## Para onde vai o tempo de quadro

Na vista da mata, qualidade alta, 34,4 ms **[medido, somas aproximadas]**:

- **~8 ms de base:** chão, céu, água, pós-processamento e o robô (a vista "sem mata nenhuma").
- **~16 ms de árvores** (perto, `_longe` e vultos). Quase tudo são os pixels das placas de folha, e não os triângulos:
  - com a resolução a 50% (um quarto dos pixels), o quadro cai 14 ms;
  - com `cull_back` nas folhas, cai 6 ms;
  - os triângulos contados quase não mudam quando as árvores somem (de 2,64 para 2,39 milhões sem as de perto).
- **~4 ms de SSAO e ~5 ms do MSAA 4x.** Os dois pesam mais justamente sobre folha e capim recortados.
- **~2,6 ms de sombra do sol.** Depois da forma de sombra (§95/96) ela ficou barata; reduzir as faixas ganha menos de 1 ms.
- **O resto:** capim, plantas, desfoque, mar e céu, de 1 a 1,5 ms cada.

Por que as folhas custam tanto **[lido + conhecimento de motor]**:

1. **Muitas camadas.** As copas do MegaKit são centenas de placas sobrepostas com recorte (`vale_tex`, `corte = 0.4`) e `cull_disabled`. Da câmera, cada pixel de copa é pintado por várias placas.
2. **`discard` em tudo.** **Todos** os materiais do vale podem descartar pixel, inclusive as cascas e pedras sem recorte, porque `fora_da_trama` (a trama da troca por distância, §57) está em `vale_tex`, `vale_folha`, `vale_solido` e `vale_base`. Shader com `discard` atrapalha a placa a descartar cedo o que está escondido. Tirar o `discard` só das cascas e pedras deu −1,8 ms **[medido]**. Testei também ligar o depth prepass no Mac: a Godot o desliga por padrão para placas da Apple (`rendering/driver/depth_prepass/disable_for_vendors` = "PowerVR,Mali,Adreno,Apple", conferido na execução). Ligado numa cópia do projeto por links, deu empate: 34,6 / 33,6 / 39,1 ms contra 34,3 / 33,5 / 39,1 sem ele **[medido]**. Ou seja, o prepass não é o caminho; o caminho é ter menos camadas de folha.
3. **Folhas pequenas na meia distância.** Entre 190 e 450 m (`_longe`) as folhas ficam com poucos pixels: triângulos minúsculos e recortados, que a GPU pinta em blocos de 2 × 2 pixels mesmo quando só um é coberto. Por isso as `_longe` custam 6 a 9 ms com pouco triângulo.
4. **MSAA 4x em todo recorte.** Na qualidade alta das fotos, o MSAA é de 4 amostras, e o jogo começa na média (2x). As medidas das fotos (34/28/82/29/31 fps) são todas da alta.

Desperdício de vértices **[lido + medido]**: a troca por distância é feita no shader (`presenca`), peça a peça. O bloco inteiro continua sendo mandado à placa enquanto alguma peça dele puder aparecer, e as peças fora da faixa viram um ponto no vertex shader. Os blocos `_longe` da mata de fora têm 200 m e começam a ser desenhados a 16 m da câmera (`Qualidade.preparar_bloco`: `190 − 34 − raio`). Os da clareira têm 400 m e são desenhados desde 0 m.

Contei, no processador, os blocos que passam pelo corte de distância e de enquadramento, e quantos dos vértices deles são de peças que aparecem:

| Vista (alta) | Perto | `_longe` | Vultos | Plantas | Capim fixo |
|---|---|---|---|---|---|
| Mata | 2,2 M vértices, 65% úteis | 3,6 M, 54% | 0,7 M, 66% | 0,8 M, 50% | 0 |
| Base | 1,1 M, 71% | 2,7 M, 46% | 1,4 M, 90% | 1,0 M, 56% | 4,8 M, 83% |
| Sobre a mata | 2,3 M, 57% | 3,9 M, 58% | 0,9 M, 61% | 1,1 M, 43% | 0 |

São de 35 a 55% de vértices jogados fora, mas o total é pequeno: 7 a 9 milhões de vértices por quadro. É por isso que "sair cedo" no vertex shader quase não ganhou (0 a 0,5 ms). Hoje esse desperdício custa pouco no M4. Ele faz a contagem de triângulos (6 a 7 milhões) parecer pior do que é, e vai pesar se a mata crescer.

## Otimizações em ordem de retorno

Ganho em ms no Mac, na vista da mata, qualidade alta, salvo onde dito. "Custo" é o trabalho de fazer: P = horas, M = um dia, G = vários dias.

| # | O quê | Ganho | Custo | Risco visual | Onde mexer |
|---|---|---|---|---|---|
| 1 | **Colisão das árvores sem refazer tudo a cada 12 m** | tira o tranco de 20 a 28 ms a cada 12 m **[medido]** | M | nenhum | `Ilha.atualizar_colisao_arvores`, `_preparar_colisao_arvores` |
| 2 | **Capim vivo fora do quadro principal** | tira 8 a 10 ms por quadro enquanto nasce capim **[medido]** | M | nenhum | `CapimVivo._criar`, `_criar_longe`, `_mmi` |
| 3 | **SSAO por nível de qualidade** (desligado na baixa, meia resolução na média) | 3 a 5 ms **[medido]** | P | baixo (a sombra de contato some ou suaviza) | `Qualidade.NIVEIS`, `Qualidade.aplicar`, `Main._ambiente_vale` |
| 4 | **Folhas `cull_back` com placas viradas para os dois lados no conversor**, ou só `cull_back` nas `_longe` | 3,5 a 6,4 ms **[medido com cull_back]** | P–M | médio: com `cull_back` puro, metade das placas some vista de trás; duplicar no conversor resolve mas devolve parte do custo | `tools/vale/pacotes_mata.py`, `vale_tex.gdshader` (shader próprio para folha) |
| 5 | **Shader sem `discard` para o que não tem recorte**, e a trama da troca só nas folhas | 1,8 ms no Mac **[medido]**; no PC não medido | P | baixo: cascas e pedras trocam sem pontilhado (escondido pela copa) | `vale_tex.gdshader` (variante `vale_tex_opaco`), `Clareira._tex_q` |
| 6 | **Antisserrilhado mais leve:** alta com MSAA 2x + FXAA, ou TAA/FSR 2 no PC; média com FXAA | 3 a 6 ms **[medido]** | P | médio: folha e capim recortados serrilham mais sem MSAA; o TAA borra o capim em movimento | `Qualidade.NIVEIS` |
| 7 | **Desfoque de fundo e mar por nível:** desfoque só na alta; mar sem cópia de tela longe da costa | 1,3 + 1,2 ms **[medido]** | P | baixo | `Main._ready` (lente), `Vale._mar`, `rio.gdshader` |
| 8 | **`_longe` mais curta e vulto/impostor mais perto** (troca do vulto de 450 para ~300 m, ou impostor em cartão a partir de 250 m) | parte dos 6 a 9 ms das `_longe` **[estimativa: 3 a 5 ms]** | M–G | médio: a forma da árvore muda mais perto; o impostor precisa ser assado no Blender | `Clareira.TROCA_VULTO`, `vulto_de`, `tools/vale/pacotes_mata.py` |
| 9 | **Blocos menores para `_longe` e plantas** (64 a 100 m) ou listas por anel refeitas no processador | pouco no M4 hoje (o "sair cedo" ganhou 0,5 ms); mais com a mata maior e no PC **[estimativa]** | M | nenhum | `Vale._mata_fora`, `Clareira._arvores_e_pedras`, `_por_bloco` |
| 10 | **Capim fixo da clareira:** tufos de 155 triângulos são 4,5 milhões na vista da base; usar o mesmo nascer por distância do capim vivo, ou um tufo leve de 30 a 50 triângulos além de 25 m | até 5 ms na base **[medido: o capim fixo custa 5,2 ms]** | M | baixo | `Clareira._capim`, `tools/vale/pacotes_mata.py` (tufo leve) |
| 11 | **Plantas do chão mais leves:** `q_flor_c` tem 1.690 triângulos, `q_moita_flor` 1.368, `q_moita` 900 e o `q_cogumelo` 880 (em grupos de três); moitas e pedras projetam sombra até 280 m com recorte | ~1 ms + sombra **[medido: plantas 1,4 ms]** | P–M | baixo | `Vale._plantas_do_chao` (`grande`), conversor |
| 12 | **Abertura:** colisão dos paredões com uma forma por variante de rocha, escalada no `CollisionShape3D`, em vez de 2 mil cascos convexos calculados | ~1,5 s a menos na abertura **[estimativa, a partir dos 1,9 s medidos]** | P–M | nenhum | `Paredoes._colisao`, `_casco` |
| 13 | **Interpolação de física da Godot** (`physics/common/physics_interpolation`) no lugar da conta à mão só do robô | não é fps: tira tremido de projéteis e efeitos a 120/144 Hz no PC **[lido]** | M | nenhum | `project.godot`, `Armadura.pos_suave`, `Main._ready` (`physics_jitter_fix`) |
| 14 | **Céu sem `TIME` no reflexo** (processo incremental; o reflexo do céu quase não aparece com rugosidade 0,9) | 0,4 a 0,8 ms **[medido]** | P | nenhum perceptível | `Main._ambiente_vale` (`sky.process_mode`) |

### Como fazer as mais importantes

**1. Colisão das árvores.** Hoje há um corpo só (`ArvoresColisao`) com 900 formas filhas. A cada 12 m todas são reescritas (raio, altura, posição, ligada ou não), e o Jolt refaz o corpo. Três caminhos, do mais simples ao mais limpo:

- **(a)** Só trocar as vagas que mudaram, comparando o conjunto de árvores novo com o antigo, e espalhar a troca por alguns quadros.
- **(b)** Formas compartilhadas por modelo e escala arredondada, só mudando a posição do `CollisionShape3D`.
- **(c)** Recomendado: criar de uma vez, na montagem, um corpo estático por árvore direto no `PhysicsServer3D`, sem nós. Algo como 33 mil corpos com 66 mil formas. O Jolt aguenta isso bem e o custo por quadro some. A dúvida é o tempo de montagem: estimo de 0,1 a 0,5 s, não medido.

Isso vale mais no PC: o Ryzen 5 5500 tem núcleo mais lento que o do M4 **[estimativa]**, e o voo a 28 m/s passa 12 m a cada 0,4 s.

**2. Capim vivo.** `_criar` faz 2.916 sorteios por bloco em GDScript. Cada um chama `mapa.agua` (que percorre os cursos d'água), `mapa.altura` e o ruído, e grava as instâncias uma a uma com `set_instance_transform`. O que fazer:

- calcular a lista num `WorkerThreadPool` e entregar ao quadro principal um `PackedFloat32Array` pronto para `multimesh.buffer`, numa chamada só;
- amostrar água e altura numa grade de 2 m, como já se faz com a cobertura;
- guardar os blocos soltos num cache pequeno, para não refazer ao voltar.

Com o trabalho fora do quadro, o `POR_QUADRO = 1` pode subir. Isso também acaba com o capim que surge aos poucos depois de um pouso.

**4 e 5. Folhas e `discard`.**

- Separar o shader da casca e da pedra (sem `discard` nenhum; a troca por distância vira um corte seco, escondido pela copa) do shader da folha.
- Na folha, testar `cull_back` com o conversor duplicando só as placas que ficam de perfil. Alternativa: `cull_back` só nas versões `_longe`, onde ninguém vê a placa por trás.
- Não vale ligar o depth prepass no Mac: testei e deu empate (ver "Para onde vai o tempo de quadro").

### O que eu NÃO faria

- **Terrain3D ou trocar o chão:** o chão custa 0,4 a 0,9 ms **[medido]**, e a §77 já mostrou empate.
- **Mexer mais nas cascatas de sombra:** de 380 m e 4 faixas para 150 m e 2 faixas ganha menos de 1 ms, e a sombra é parte do visual.
- **Cortar triângulos de árvore "porque são 7 milhões":** a contagem engana (ver "desperdício de vértices"); o custo está nos pixels.
- **Reescrever em C++/GDExtension agora:** os dois pontos quentes de processador saem com as soluções acima. O resto dos scripts (bichos, máquinas, HUD) não aparece nas medidas (§63 e o "bichos e mechas parados" do `--perf`).
- **Baixar a resolução de propósito no Mac como solução:** ela ganha muito (50% tira 14 ms), mas o jogo é sobre olhar a paisagem. Deixaria como opção de escala 3D com FSR 1, não como padrão.

### Qualidade ajustável (o PC é mais forte)

Proposta para `Qualidade.NIVEIS` **[estimativa, montada a partir dos Δ medidos]**:

| | Baixa | Média | Alta | Ultra (nova, só PC) |
|---|---|---|---|---|
| SSAO | desligado | meia resolução, qualidade baixa | ligado | ligado, alta |
| Antisserrilhado | FXAA | MSAA 2x | MSAA 2x + FXAA | MSAA 4x ou TAA |
| Desfoque de fundo | desligado | desligado | ligado | ligado |
| Troca das árvores (`troca`) | 0,6 | 0,8 | 1,0 | 1,2 |
| Vulto a partir de | 300 m | 380 m | 450 m | 600 m |
| Capim cheio até | 16 m | 34 m | 60 m | 80 m |
| Sombra | 2 faixas, 130 m | 4 faixas, 220 m | 4 faixas, 380 m | 4 faixas, 500 m |
| Escala 3D | 0,77 com FSR 1 | 1,0 | 1,0 | 1,0 |

Também pede um contador de fps "de verdade" no F3: hoje ele mostra o `TIME_PROCESS`, que no Metal inclui a espera pela placa. E um voo de teste gravado que devolva média e pior 1%, como a §7 já planejava. Meu `_voo` (no `medir.gd`) é um começo.

### 60 fps na mata é realista?

- **No Mac (M4, 1600 × 900):** a mata na alta está em 34 ms. As otimizações 3 a 7 juntas tiram de 12 a 17 ms. Somam-se de forma imperfeita, porque SSAO, MSAA e folha disputam os mesmos pixels. Isso põe a alta perto de 20 ms (50 qps), e a baixa perto de 60 **[estimativa]**. Para 60 qps na alta seriam precisos impostores nas `_longe` (item 8) ou menos camadas de folha por copa.
- **No PC (RTX 3060 Ti, 1440p):** não medi. Pela conta da resolução, a mata a 1600 × 900 tem ~16 ms fixos e ~18 ms que crescem com os pixels; 1440p tem 2,56 vezes os pixels. Supondo que uma 3060 Ti faça as duas partes de 2,5 a 3 vezes mais rápido que o M4 (não conferido), isso dá algo entre 20 e 28 ms na alta de hoje e entre 13 e 18 ms com as otimizações **[estimativa grosseira, ±50%]**. Ou seja: 60 fps na mata do PC parece alcançável na média, talvez na alta. O que mais ameaça o PC são os **trancos de processador** (itens 1 e 2), não a média de fps.

## Arquitetura e dívida técnica

**O que está frágil [lido]:**

- **Hierarquia `Ilha` → `Clareira` → `Vale`.** O `Vale` é uma ilha de 3 km com um buraco no meio onde mora a `Clareira`, que tem a sua própria grade de 1 m, o seu próprio capim fixo (75 mil tufos), a sua própria mata em blocos de 80/400 m e a sua lagoa. `altura`, `agua` e `normal_em` decidem a cada chamada em qual das duas grades olhar (`_dentro`), com mistura na borda (`BORDA_DE`/`BORDA_ATE`). Isso dá dois jeitos de fazer cada coisa: o capim fixo custa 5 ms na base e o vivo não; os blocos `_longe` da clareira são de 400 m e os de fora de 200 m. Quando o jogo crescer, cada coisa nova vai ter de ser feita duas vezes ou ganhar um `if`. A `Ilha` pequena só serve à bateria do voo (`--teste`). **Vale refatorar:** a clareira deveria ser só um "carimbo" de altura e cobertura sobre a grade do vale, com o capim vivo também lá dentro. É o refator com mais retorno, mas não é urgente; eu faria quando mexer no capim (item 10).
- **Arquivos gigantes:** `capturas_vale.gd` (2.554 linhas), `testes_vale.gd` (2.197), `fundicao.gd` (1.364), `vale.gd` (1.224), `armadura.gd` (1.116). O das capturas é uma lista de `if "--x" in args` com vistas escritas à mão. Dá para virar dados: um dicionário de nome → lista de vistas. Não é urgente.
- **Estado global em `static var`:** 77 classes, com `static var` em `Arsenal` (11), `Fundicao` (11), `Sumidouro` (11), `MelhoriasVisual` (9), `BaseVale` (8) e outras. Funciona num processo por partida, mas é por isso que testes e fotos dependem de `Guardado.ativo`, `Melhorias.tudo` etc. serem acertados na ordem certa em `Main._ready`. Uma futura "voltar ao menu e começar de novo" vai esbarrar nisso.
- **Montagem por código em `Main._ready`:** são 300 linhas de `X.new()`, `x.armadura = ...`, `add_child`. Está legível, mas tudo depende da ordem. Um registro simples (cada sistema recebe `main` e pega o que precisa) ou sinais de "mundo pronto" reduziriam isso. Não vale a pena agora.
- **Cache (`Cache`):** a chave é a soma das datas de **todos** os arquivos de `scripts/` e do mapa. Mudar uma linha da HUD joga fora o cache do mundo inteiro, e a abertura volta a 8,7 s (§79). Duas cópias do jogo rodando juntas (como hoje, com quatro agentes) gravam os mesmos arquivos ao mesmo tempo, sem trava; o pior caso é um arquivo corrompido, e aí o `get_var` falha e o passo é refeito. A data também muda com `git checkout`. **Vale melhorar:** chave por passo, com a versão do gerador escrita à mão (`const VERSAO_PLANTAS := 3`) mais o hash dos dados de entrada; gravar num arquivo temporário e renomear. E guardar `PackedFloat32Array` em vez de `Array` de `Transform3D`, que é lento de ler.
- **Testes:** são duas baterias longas (a do vale leva de 5 a 9 min) que montam o mundo inteiro. Não há teste rápido de unidade para as contas puras (troca por distância, `presenca`, colisão de árvore, capim). Um teste de desempenho com limite ("mata fechada abaixo de X ms") pegaria regressões como a das copas (§95). O salvamento não tem teste (§63).
- **Tamanho da build (139 MB):** o motor ocupa uns 70 a 80 MB **[estimativa]**. Os sons são WAV com QOA (`compress/mode=2`). O `mech00_anim.fbx` tem 25 MB de fonte. Nada urgente. Para encolher, o caminho seria Ogg nos laços longos e conferir o que entra do `mech00`.

**O que vai doer quando o jogo crescer:**

- Mais árvores, com cada bloco virando um MultiMesh por modelo e por superfície. Já são 28 mil MultiMesh e 41 mil nós; o processador de desenho está em 2 a 4 ms (folgado no M4, menos no Ryzen 5500).
- Cada sistema novo de "nasce perto do robô" (capim, peixes, bichos) feito em GDScript no quadro principal.
- O `vale.gd` e o `clareira.gd` cresceriam juntos, por causa da hierarquia.

**Refatorar agora:** a colisão das árvores e o capim fora do quadro (são também os itens 1 e 2). **Nunca, ou só se doer:** trocar a montagem por código por cenas `.tscn`. A montagem por código é uma força do projeto: dá para refazer o mundo, testar e fotografar por linha de comando.

## Controles e câmera (pelo código)

**O que está bem feito [lido]:**

- Quase todas as suavizações são independentes do quadro (`1 - exp(-k * delta)`).
- O robô é desenhado interpolado entre passos da física (`Armadura.pos_suave`).
- O atraso da câmera foi corrigido para não depender do tempo do quadro (§90).
- O mouse gira a câmera direto no evento (`_unhandled_input`), sem esperar o quadro.
- O analógico direito tem zona morta de 0,12 e curva quadrática.
- Há tolerância de 0,15 s para pular depois de sair da beira (`_fora_chao`).

**O que costuma dar sensação ruim [lido; nada jogado]:**

1. **Câmera colide com as copas.** O raio da câmera (`CameraVoo._process`) bate na camada 2, que tem os troncos e também as cápsulas das copas (`_formas_copa`). Voando rente à mata ou andando sob a copa, a câmera vai pular para perto do robô quando uma copa passa entre os dois. Além disso, o raio é fino e a câmera encurta na hora, mas volta suavizada por `_dist`, o que dá "entra seco, sai mole". Sugestão: tirar as copas da máscara da câmera (deixar só tronco e chão), usar `shape_cast` com esfera de 0,25 m e suavizar a entrada também, com um limite.
2. **Tranco de processador a cada 12 m** (item 1): no voo, é provavelmente parte dos "trancos" que o usuário viu no PC (§90). No voo de teste sobre a mata, a colisão é refeita 41 vezes em 20 s e põe o p99 de 48 para 65 ms.
3. **Interpolação só do robô.** O jogo roda a física a 60 Hz e só o robô é interpolado. Projéteis, granadas e efeitos que andam em `_physics_process` (`Tiro`, `EfeitosAgua`, `EfeitosMato`, `Fundicao`) vão tremer num monitor de 120/144 Hz. A inclinação do corpo (`ArmaduraVisual.atualizar`, `_acel`) deriva a velocidade da física pelo `delta` do quadro: acima de 60 qps, ela alterna entre 0 e um pico. A interpolação de física da Godot (item 13) resolve tudo de uma vez.
4. **O capim reage à posição da física** (`EfeitosMato._process` usa `armadura.global_position`, e não `pos_suave()`). É pequeno, mas o capim "anda aos degraus" quando o quadro não bate com a física.
5. **Pulo sem memória.** Apertar o X um instante antes de tocar o chão gasta o pulo duplo no ar em vez de guardar o pulo para o pouso. Um buffer de 0,1 s em `_ar`/`_chao` é o padrão do gênero.
6. **Zona morta do analógico esquerdo de 0,2** (o padrão de `Controles._garantir`). Para o DualSense, 0,1 a 0,12 costuma bastar; com 0,2 a passada lenta começa tarde. O acelerador do voo ainda soma 0,15 por cima (`_voo`: `absf(mov.y) > 0.15`), então andar devagar no voo é difícil. Vale uma zona morta só, radial, e ajustável na pausa.
7. **Entrada na física a 60 Hz.** Os botões são lidos em `_physics_process`, então um aperto leva até 16 ms para valer, mesmo a 144 qps. É aceitável para este jogo e não mexeria. Com o Mac a 25 a 30 qps, a latência real é a do quadro (35 a 40 ms), que é o argumento de jogabilidade para os cortes acima.
8. **Sensibilidade do analógico em 2,8 rad/s no fim**, sem aceleração ao segurar no fim. Para virar 180° são 1,1 s. É uma escolha de jogo calmo; um leve ganho depois de 0,3 s no fim do curso costuma agradar sem atrapalhar a mira.

## O que não deu para verificar

- **O PC:** nada medido nem jogado no Bazzite (a regra era não mexer no PC remoto). As contas para o PC são estimativas.
- **Tempo de placa separado do de processador no Metal:** a medida da Godot volta 0, então só tenho o tempo do quadro inteiro.
- **A conta de vértices desperdiçados** é uma aproximação feita no processador: enquadramento pela caixa do bloco, distância pela origem de cada peça. Não é uma leitura da placa.
- **Quanto da sobreposição de folhas é de cada árvore:** não tenho ferramenta de contagem de sobreposição de pixels no Metal pela linha de comando. O custo das folhas foi inferido pela resolução a 50% e pelo `cull_back`.
- **Visual dos experimentos:** as trocas de shader (`cull_back`, sem trama, sem `discard`) foram só medidas, não fotografadas; o risco visual na tabela é leitura minha.
- **Noite, chuva e vaga-lumes:** medi só às 15h, com sol.
- **Fundição, cavernas e Sumidouro** (luzes, partículas e muitas máquinas juntas): não medi.
- **Memória ao longo de uma partida longa** (blocos de capim e cardumes criados e soltos): não medi vazamento.
- **Abertura sem cache e na build exportada:** usei os tempos do `--tempos` com outros agentes rodando; a primeira abertura depois de mudar um script não foi cronometrada por mim.

Scripts usados: `/private/tmp/claude-501/-Users-welington-Documents-Projects/09f36a4f-6821-4522-b29d-7634c33b4bcf/scratchpad/dev/medir.gd` (medição, experimentos de shader, voo) e `rodar.sh` (espera o Mac ficar livre e anota quem rodou junto). Saídas: `full1.log`, `sh2.log` e `voo1.log` na mesma pasta.
