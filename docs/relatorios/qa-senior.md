# Relatório de QA sênior: Faísca 2 (2026-11-19)

Papel: QA sênior. Foco em defeitos, casos de borda, riscos de regressão e buracos na cobertura de teste. Base: `main` em `a55938a`, Godot 4.7.2, Mac, com outros três agentes usando o Godot ao mesmo tempo (por isso nenhum tempo ou fps daqui vale como medida).

## Resumo

1. As duas baterias passam (VOO OK 95, VALE OK 84), e a do vale também passa sem cache (`--sem-cache`), com o mesmo resultado.
2. Achei um defeito que bloqueia o jogo e reproduzi rodando: entrar em pane e escolher **Voltar à base** na pausa deixa a tela preta para sempre (até outra pane ou reabrir o jogo).
3. As telas brigam entre si: memória + Esc, memória + Options e oficina + drone deixam o jogo rodando atrás de um menu ou com o robô solto dentro do cilindro (os três confirmados rodando).
4. **Apagar o progresso** não apaga de verdade: o próprio jogo regrava quase tudo da memória em até 60 s, ou ao sair (confirmado lendo o código).
5. A maior falha de cobertura é o que as baterias não exercitam de propósito: salvar e carregar (`Guardado.ativo` é falso nos testes), a pausa, a mistura de telas, outras taxas de quadro e a build exportada do PC.

## Como foi feito

- As duas baterias rodaram sem janela, uma de cada vez. A do vale rodou duas vezes: com o cache e com `--sem-cache`.
- Revisei o código do robô, da pausa, das memórias, das peças, da oficina, da Fundição, do save, do cache, dos controles, da câmera e do limite do mar.
- Para confirmar rodando sem mexer no projeto, escrevi duas sondas fora dele (`/private/tmp/claude-501/-Users-welington-Documents-Projects/09f36a4f-6821-4522-b29d-7634c33b4bcf/scratchpad/qa/qa_probe.gd` e `qa_probe2.gd`). Elas carregam a cena com `-- --teste-vale --basico`, então não leem nem gravam o save, e tiram a bateria do caminho. Rodam com `godot --headless --path . -s <sonda> -- --teste-vale --basico`. Servem de ponto de partida para os testes que faltam.
- Não tirei fotos: os defeitos achados são de lógica, e os números da sonda bastam como prova.

## Resultado das baterias

| Bateria | Resultado | Tempo de parede (máquina ocupada) | Avisos do motor |
|---|---|---|---|
| `--teste` | **VOO OK (95 pontos)** | 2:02 | `8 ObjectDB instances were leaked at exit` e `1 resources still in use at exit`, só ao sair |
| `--teste-vale` | **VALE OK (84 pontos)** | 4:46 | nenhum |
| `--teste-vale --sem-cache` | **VALE OK (84 pontos)**, mesmos pontos | 4:51 | nenhum |

O que a leitura das saídas mostra:

- **`--teste` não testa o robô do jogo.** Ele roda na ilha pequena com `porte 1.0` e `vel_chao 1.0` (`main.gd:72-76`), e o jogo usa 0,48 e 0,7. As 95 checagens de voo são de um robô que não existe na build. Só a bateria do vale confere o robô de verdade, e cobre menos casos de voo.
- **Os textos dos pontos estão velhos e as folgas são largas.** Exemplos: "voo reto chega a ~30 m/s (19.3)", "arrancada, ~45 m/s (26.4)", "segura a ~18 m/s (11.6)". `VOO_ALVO` hoje é 18. "Mantém a altura com a mira no horizonte (-19.7 m)" passou contra um limite de 25 m: é o primeiro candidato a falhar de vez em quando.
- **A bateria do vale varia de uma rodada para outra.** O espalhamento dos robôs da Fundição deu 9 m numa rodada e 12 m na outra. Passa nas duas, mas mostra que há sorteio sem semente fixa.
- **O cache está coerente.** Sem cache, o mundo gerado dá os mesmos 84 pontos e as mesmas contagens: 16.602 árvores, 2.912 blocos de parede, 15.798 triângulos nos gigantes. É o caminho que a primeira abertura de cada build nova faz no PC.

## Defeitos

Confiança: **rodando** = reproduzido pela sonda; **código** = certo pela leitura, não rodado; **suspeita** = provável, não confirmado.

| # | Gravidade | Onde | Como reproduzir | Confiança |
|---|---|---|---|---|
| D1 | **Bloqueia** (até reabrir o jogo) | `pausa.gd:399` (`_voltar`) chama `Armadura.recomecar` (`armadura.gd:338`), que zera `em_pane` sem emitir `saiu_pane`; `pane.gd:35` escurece e só `pane.gd:53` clareia | Levar 3 golpes de máquina. Nos ~7 s da pane, Options e depois **Voltar à base**. A tela fica preta, com "curto no motor · voltando à base", e o jogo segue por baixo. Sonda: 9 s depois, preto com alfa 1,00, `em_pane` falso. Só outra pane completa clareia | rodando |
| D2 | Grave | `memorias.gd:224` lê `ui_cancel` em `_process`; Esc também é `menu` (`controles.gd:77`) e abre a pausa (`pausa.gd:331`) | Tocar num cristal e apertar **Esc** no teclado, como o próprio rodapé manda (`memorias.gd:163`). A pausa aparece, a memória fecha e o jogo fica **despausado** com o menu na tela. Sonda: o robô andou 2,01 m com a pausa aberta (pode levar tiro) | rodando |
| D3 | Médio | `pausa.gd:396` solta a pausa sem saber quem pausou | Memória aberta, **Options** e depois **Continuar**. O jogo volta a rodar atrás do texto da memória, sem HUD. Sonda: andou 2,04 m atrás do texto | rodando |
| D4 | Médio | `pausa.gd:275` → `Guardado.recomecar_progresso` só zera o arquivo. Ficam na memória `Melhorias`, `Arsenal`, `Memorias.lidas` e `locais.visto`, que são regravados por `main.gd:512` (a cada 60 s e ao sair), `Arsenal.guardar` (a cada robô vencido e a cada toque no L1, `roda_armas.gd:85`), `Melhorias.guardar` (pegar ou instalar peça) e `Memorias.abrir` | Apagar e sair do jogo: ao abrir, os lugares visitados e a hora voltaram, e peças e armas sumiram (apaga pela metade). Apagar e seguir jogando: quase tudo volta. O botão diz "vale na próxima vez que abrir o jogo" | código |
| D5 | Médio | `oficina.gd:431` (`entrar` não confere `travado`), `oficina.gd:532` (o convite aparece com o robô travado), `pecas_mundo.gd:282` (o drone solta o robô sem saber da oficina) | Pegar uma peça e pousar na boca do cilindro. Enquanto o drone vem, apertar **quadrado**. A oficina abre, o drone termina e destrava o robô **dentro** dela. Sonda: `travado` falso com a oficina aberta, e o robô andou 0,33 m com o analógico. A peça é instalada por trás da tela | rodando |
| D6 | Médio (uso) | `pecas_mundo.gd:257-266` | Com peça na mão, pousar perto de um mecha ou no meio de uma onda (a peça do scanner fica na frente da Fundição). O drone prende o robô de 3 a 5 s, e as máquinas seguem batendo, o que pode virar pane. Falta conferir ameaça por perto e a fase da Fundição | código |
| D7 | Médio | A colisão do chão é um `HeightMapShape3D` de ±1.500 m (`vale.gd:931`, `F_META`), mas a pane do mar só vem a 550 m da costa (`limite_mar.gd:9`), e há terra até ~1.490 m (Arquipélago Raso) | Voar para leste além do Arquipélago e mergulhar. Sonda: em x = 1.510 já não há chão (costa a 138 m, sem aviso). Nadando para baixo, o robô atravessou o fundo desenhado (-7,9 m) e, abaixo de -40 m, foi **teletransportado para o começo** sem pane nem fade (`armadura.gd:440`). Falta conferir o que se vê lá embaixo | rodando |
| D8 | Leve | `pausa.gd:331-344`: `menu` (Esc) vem antes de `ui_cancel` | Na pausa, entrar em Comandos ou Ajustes e apertar Esc: fecha a pausa inteira, ao contrário do rodapé "O ou Esc: voltar" | código |
| D9 | Leve | `pausa.gd:35` | A tabela de comandos diz "Parar no ar · frear: L2 · O / F · C". No voo, O/C é a manobra (giro e tranco, §88), que não aparece na tabela | código |
| D10 | Leve | `pausa.gd:374` captura o mouse; a oficina precisa dele visível (`oficina.gd:598`) | Oficina aberta, Options, Continuar: com mouse, os botões da oficina param de responder. Com **Voltar à base** a oficina fica na tela, com a câmera dela e o robô travado na base. Sonda: fase ABERTA, tela visível, câmera da oficina ativa. Sair com O devolve o robô à boca do cilindro | rodando (o Voltar); código (o mouse) |
| D11 | Leve (brecha) | `fundicao.gd:1275-1289`: a perda de metade dos materiais só vem com `em_pane`; os materiais são gravados a cada robô vencido (`fundicao.gd:1152`) | Apanhando no meio da onda, **Voltar à base** ou sair do jogo: fica com tudo ("Fundição desligada", sem perda) | código |
| D12 | Leve, risco no PC | `project.godot` sem `window/stretch/mode`; interface em pixels fixos (fontes de 13 a 30 px, `hud.gd`); tela cheia forçada no Linux (`main.gd:360`), sem opção de janela nem de resolução | Num monitor ou TV 4K, as letras ficam com metade do tamanho. Em 1280x720 ou 800, a página de comandos (24 linhas) pode não caber. Só a tela de carregamento escala (`carregando.gd:85`) | código (efeito: suspeita) |
| D13 | Leve, Mac | `controles.gd`: sentar é Ctrl, e as setas também andam | Ctrl + seta é atalho do macOS (Mission Control e trocar de mesa): sentar segurando a seta pode tirar a tela do jogo | suspeita |
| D14 | Médio, risco | Nenhum `joy_connection_changed` no projeto | O DualSense desligar (bateria ou Bluetooth) no meio do voo: o jogo não pausa nem avisa. Não deu para simular a desconexão sem janela | suspeita |
| D15 | Leve | `memorias.gd:224` fecha no `just_pressed` em `_process`; ao contrário da pausa (`pausa.gd:392`), não espera soltar o botão | Em tela de 120/144 Hz, fechar a memória com X ou O pode chegar ao robô no passo seguinte da física (pulo ou esquiva). A 60 Hz sem janela não aparece | suspeita |
| D16 | Leve | `pausa.gd:345`: o clique que recaptura o mouse também é `atirar` (`tiro.gd:110`) | Mac: Cmd+Tab e voltar com um clique: o robô dá um tiro | suspeita |
| D17 | Leve | `ilha.gd:504-540`: até 450 árvores com colisão num raio de 70 m, percorridas por célula a partir do canto, não pela distância | Numa mata muito densa, as árvores mais perto do robô podem ficar sem colisão. A média do vale dá ~50 árvores no raio, então só pega onde a mata é muito fechada | suspeita |
| D18 | Leve | `pecas_mundo.gd:244` e `memorias.gd:239`: a coleta é medida por quadro desenhado, com raio de 1,15 m | Com fps baixo e voo rápido (28 m/s a 20 qps são 1,4 m por quadro), dá para passar raspando a caixa sem pegar | suspeita |
| D19 | Leve | `guardado.gd:20-30`, `melhorias.gd:43-46`, `memorias.gd:61` | Save ilegível: volta ao padrão em silêncio e o primeiro salvamento (em até 60 s) grava por cima, sem cópia. Tipo errado (`"pecas": null`) dá erro no `as Array` + `duplicate()`. Não há campo de versão. Uma queda no meio da gravação é improvável, porque o FileAccess da Godot grava num `.tmp` e renomeia | código |
| D20 | Leve | `user://` vem de `config/name` | O save está em `.../app_userdata/Faísca 2- Em Busca do Sossego/`, e já existe a pasta `Jogo de voo (teste)` de antes da troca de nome. Trocar o nome de novo perde o save sem aviso (falta `use_custom_user_dir`) | código |
| D21 | Leve (dev) | `cache.gd:21-23` | No editor, a chave do cache olha só `scripts/` e `assets/vale/mapa`: trocar um modelo em `assets/` sem mexer em script não invalida o cache. Os `rebaixo_*.bin` velhos se acumulam (há um de 18/11) | código |

Não é defeito, mas não tem teste nem estado no código: juntar as 10 peças e as 10 memórias não dispara nada. Não há fim nem marca de "completo".

**Sobre as pendências das seções 97 e 98:**
- Confirmo: "trancos da câmera" e "robôs da forja rodando" continuam sem teste próprio, e o afundamento na ladeira (§86) também.
- Corrijo uma descrição: no vale, a pane do mar sempre leva à **base**, não à praia. `pane_forcada` prefere `base` quando ela existe (`armadura.gd:217`), e a `praia_perto` não é usada no jogo. O comentário de `LimiteMar` e a seção 86 falam em praia.
- O estado `FREAR` ficou inalcançável, como a §88 diz, mas o visual e a vibração ainda o tratam.

## Buracos de cobertura

1. **Salvar e carregar: zero.** `Guardado.ativo` é falso em `--teste`, `--teste-vale` e nas fotos (`main.gd:44`). Ficam sem teste a retomada (hora, lugares, peças, memórias, arsenal), Apagar o progresso, save corrompido ou velho e o salvamento ao sair.
2. **Pausa: um ponto só** ("sair da pausa com a bolinha", `testes.gd:512`). Voltar à base, Ajustes, Apagar, Sair, Comandos e Esc não têm teste.
3. **Telas uma sobre a outra:** pausa × memória × oficina × pane × roda de armas × scanner × drone instalando. Todos os defeitos de D1 a D5 e D10 moram aqui.
4. **Entrada real:** quase tudo usa `Input.action_press`. Eventos de verdade só nos botões do controle (`_controle`) e no D-pad. Nenhum evento de teclado, então o Esc duplo (D2) não poderia ser pego. Desconexão do controle também não.
5. **Taxa de quadros:** as baterias andam por `physics_frame` a 60 Hz sem janela. Nada roda a 20 ou 30 qps nem a 120 ou 144 Hz, e a coleta, as memórias, a câmera e os bichos ficam em `_process`.
6. **Qualidade:** testes e fotos sempre em "alta" (`main.gd:487`). O padrão do jogador é "média", e "baixa" nunca é vista.
7. **O robô de verdade no voo:** a bateria de voo usa outro porte (ver acima).
8. **A borda do mapa:** o mar é testado só a 596 m, num rumo. Nada confere que há chão em todo lugar aonde o robô chega antes da pane (D7).
9. **"Preso" e "atravessou":** só há pontos fixos (degrau, aqueduto, gigantes, telhado da forja). Não há uma varredura que solte o robô em muitos pontos e confira que ele fica de pé e sai andando ou voando.
10. **A build exportada:** nada roda o `.x86_64`. Ficam de fora a chave do cache pelo executável, a tela cheia forçada e os caminhos com maiúsculas e minúsculas no PCK. Eu varri os `res://` literais e não achei erro de maiúscula, mas os caminhos montados com `%s` só foram conferidos por amostra (peixes, sons).

### Testes automáticos que faltam (em ordem de valor)

1. **Pausa em cada estado:** voo, nado, pane, oficina, memória, roda, scanner e drone instalando. Sair por Continuar, Voltar à base e Esc, e conferir `paused`, as camadas visíveis (alfa da `Pane`), `travado` e a câmera atual. As sondas já fazem quatro destes casos.
2. **Save de ida e volta:** trocar `Guardado.ARQUIVO` por uma variável estática para apontar a `user://qa_*.json`. Gravar, recarregar e comparar. Cobrir arquivo truncado, tipos errados, save sem as chaves novas, e Apagar → `guardar_progresso` → continua apagado.
3. **Oficina × drone:** com peça na mão na boca do cilindro, o quadrado não abre enquanto `travado`, ou a oficina assume a instalação.
4. **Borda:** para cada ponto a `LimiteMar.PANE - 10` m da costa, em 16 rumos, um raio para baixo tem de achar chão.
5. **Varredura de preso:** 300 pontos secos ao acaso. Soltar de 2 m, esperar o chão, andar 2 m em quatro rumos e decolar. Sem chão a menos de 3 m, ou sem conseguir sair, é falha.
6. **Ritmo:** repetir os pontos de nado, pouso e coleta com `Engine.physics_ticks_per_second` 30 e 120 e com `Engine.max_fps = 20`. Incluir pegar uma peça em voo a 28 m/s.
7. **Campanha curta com `--basico`:** teleportar pelas 10 peças e pelos 10 cristais, conferir os contadores "N de 10" e um estado final.
8. **Ladeira (§86):** correr morro acima logo depois de um pouso e conferir que `_degrau_y` e a altura sobre o chão ficam dentro de um palmo.
9. **Endurecer o que já existe:** fixar as sementes da Fundição, atualizar os textos do `--teste` e apertar "mantém a altura".

## Riscos por plataforma

**Mac** (roda pelo editor; não há preset de exportação para Mac):
- Janela fixa de 1600x900, sem tela cheia nem troca de resolução.
- Ctrl + setas (D13) e o clique de volta depois do Cmd+Tab (D16).
- A tela ProMotion de 120 Hz é o caso mais provável de D15 e de diferenças de ritmo.
- O Mac nunca testa a build: o que só existe no executável (chave do cache e PCK) só aparece no PC.

**PC Linux (Bazzite, DualSense)**:
- Tela cheia forçada, com a interface em pixels fixos (D12). Em TV ou 4K, conferir a leitura.
- Primeira abertura de cada build nova sem cache: o mundo é gerado do zero. Confirmei que o resultado é o mesmo, mas a carga é mais longa.
- A chave do cache é o nome e a data do executável: uma cópia que preserve a data com conteúdo novo usaria cache velho (improvável com export novo).
- DualSense: desconexão (D14) e diferença entre USB e Bluetooth. A vibração no Linux depende de permissão de hidraw.
- No Game Mode (gamescope), a resolução imposta pode não ser a do monitor.
- Primeira compilação de shaders no Vulkan: engasgos no começo.

## Plano de teste manual (em ordem de risco)

Antes do item 4, copiar `faisca2.json` (no Mac fica em `~/Library/Application Support/Godot/app_userdata/Faísca 2- Em Busca do Sossego/`).

| # | Onde | O que fazer | O que olhar |
|---|---|---|---|
| 1 | Mac e PC | Levar 3 golpes de um mecha; durante a pane, Options → Voltar à base | A tela tem de clarear (D1) |
| 2 | Mac (teclado) e PC | Tocar um cristal e apertar Esc; em outro, Options → Continuar | O jogo não pode rodar atrás do menu nem do texto (D2, D3) |
| 3 | Mac e PC | Pegar a antena, pousar na boca do cilindro e apertar quadrado enquanto o drone vem | O robô não pode andar dentro da oficina (D5) |
| 4 | Mac | Pausa → Ajustes → Apagar; Sair; abrir de novo; depois apagar e jogar 2 minutos | O que voltou: lugares, peças, armas, memórias (D4) |
| 5 | PC | Jogar 10 minutos na TV ou monitor de verdade | Ler HUD, pausa, memória e oficina de onde se joga (D12) |
| 6 | PC | No meio do voo, desligar o DualSense (segurar PS) e religar | Para onde vai o robô; se o jogo pausa (D14) |
| 7 | Mac e PC | Pegar uma peça perto de um mecha e outra na frente da Fundição em onda | Quanto tempo fica preso apanhando (D6) |
| 8 | PC | Voar a leste além do Arquipélago Raso, a uns 200 m, e mergulhar fundo | O fundo some? Volta ao começo sem fade? (D7) |
| 9 | Mac 120 Hz e PC | Fechar memória e pausa com X e com O, várias vezes; correr morro acima logo depois de pousar | Pulo ou esquiva fantasma (D15); afundar no chão (§86) |
| 10 | Mac e PC | Voo reto e curvas longas a 28 m/s; a forja com uma máquina atrás de uma planta | Trancos da câmera (§90) e a máquina que roda em volta (§89) |
| 11 | Mac e PC | Pausa → Qualidade baixa e média; abrir a oficina com o mouse depois de uma pausa | Capim e sombra em cada nível; botões com o mouse (D10) |
| 12 | Mac | Sentar (Ctrl) segurando uma seta; Cmd+Tab e voltar clicando | D13, D16 |
| 13 | PC | Primeira abertura de uma build nova | O tempo até jogar; se o mundo bate com o do Mac |

## O que não deu para verificar

- Jogar de verdade com controle e teclado, ver em movimento e ouvir: nada aqui substitui o teste na mão.
- O PC e a build exportada (regra: não mexer no PC remoto). Os riscos do Linux saem da leitura do código.
- A desconexão real do DualSense e a vibração real.
- Telas de 120 ou 144 Hz e taxa de quadros baixa: a 60 Hz sem janela esses casos não aparecem (D15, D18).
- Desempenho, de propósito: é com o game dev, e a máquina estava ocupada por outros três Godot.
- O que se vê no fundo do mar além de 1.500 m (D7): confirmei só a falta de colisão e o teletransporte.
- O comportamento numa mata densa de verdade (D17): estimei pela média, não contei árvores por ponto.
