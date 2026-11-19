# Relatório do jogador tester: Faísca 2, Em Busca do Sossego

Data: 2026-11-19. Papel: jogador comum, curioso e exigente (não programador).

**Como avaliei, sem rodeios:** não joguei com as mãos. Vi fotos tiradas pelo próprio jogo (pastas `tools/capturas/tester_dia`, `tester_base`, `tester_hud`, `tester_menus`, `tester_memoria`, `tester_noite`, `tester_chuva`) e as imagens de `docs/visual`, `docs/vale` e `docs/mapa`. O resto saiu da leitura do código (`scripts/`, `scripts/vale/`) e da doc (`docs/JOGO-VOO.md`). Cada achado vem marcado:

- **[foto]**: visto em foto;
- **[código]**: lido no código;
- **[dedução]**: o que eu acho que vai acontecer na mão de quem joga, a partir das duas coisas acima.

Nada do que digo sobre sensação de controle, ritmo do voo ou som foi sentido de verdade.

---

## Resumo em 5 linhas

1. A ilha é bonita de longe e de cima, e os marcos altos (Serra, Fundição, Torres do Vento, Farol) chamam para ir até eles: isso funciona.
2. O jogo não ensina nada nem dá rumo: abre direto no robô, sem tela inicial, sem dica de botão, e a peça mais perto nem aparece na primeira vista.
3. Os botões fazem coisas demais, e o X (o "pular" que toda criança aperta) derruba o robô do voo; a tabela de comandos da pausa está desatualizada.
4. Não há mapa nem lista do que falta, e as memórias não têm sinal nenhum: numa ilha de 3 km, depois de meia hora você não sabe o que já achou nem para onde ir. E quando acha tudo, não acontece nada.
5. No chão, o capim cobre a câmera, o robô, os bichos e a mira; de cima, o rio parece estrada de paralelepípedo e o campo é um verde-limão sem fim.

---

## O que funciona

- **Marcos que puxam o olho.** Do alto (foto `tester_dia/v7_voo_alto.png`, `tester_hud/h3_voando.png`) se veem a Serra, o arco da Fundição, as Torres do Vento no horizonte e a Torre Caída. É o jeito certo de guiar sem setas. [foto]
- **Errar custa pouco.** Não há dano de queda, superaquecer só derruba e o robô se recompõe em 1,4 s, e a pane leva de volta à base com o drone. "Voltar à base" na pausa resolve quem se perdeu. Para criança, isso é ótimo. [código: `armadura.gd`, `pane.gd`, `pausa.gd`]
- **O ciclo do calor tem ideia boa.** Voar esquenta, mergulhar e passar na cachoeira zera, a chuva esfria. Dá ritmo ao voo e faz a água valer a pena. O aviso "resfriado" em azul é claro. [código + foto `h4_superaquecido.png`]
- **O drone colega.** Fala em bipes, comemora, instala a peça onde você estiver, vem buscar na pane. Ele é o personagem com mais carisma do jogo. [código `drone_colega.gd`, `pecas_mundo.gd`]
- **"Lugar descoberto · N de M".** Dá o gostinho de colecionar lugares só por chegar neles. [código `hud.gd`]
- **Os textos das memórias.** Curtos, tristes sem ser pesados, coerentes com a história (o do Casco Encalhado fecha bem). [código `memorias.gd`, foto `docs/vale/ideias_2026_11_18.jpg`]
- **A pausa e a oficina** estão limpas e legíveis, com foco laranja bem visível e explicação de cada botão. [foto `tester_menus/n6_pausa.png`, `n3_oficina_pecas.png`]
- **A base de noite** tem clima: luz verde-água, ferrugem, vaga-lumes. [foto `tester_base/b11_noite.png`]
- **A noite não é breu.** Às 21h30 dá para ver o relevo, as estrelas e as árvores com sombra de lua, e a Fundição brilha laranja ao longe, como um farol (`tester_noite/v7_voo_alto.png`, `v4_campo_aberto.png`). Criança não fica perdida no escuro. [foto]
- **A chuva é bonita:** céu lilás, gotas finas, verde mais fundo (`tester_chuva/v4_campo_aberto.png`). E ela esfria o motor, então tem uso. [foto + código]
- **Tela de carregamento** com o robô voando na linha de progresso: dá identidade logo na abertura. [código `carregando.gd`, doc §74]

---

## Problemas, do mais grave ao menos grave

### 1. O jogo não ensina nada e não dá o primeiro passo [código + foto]

- **Onde:** abertura (`main.gd`: depois da carga o mouse é capturado e pronto); primeira vista `tester_base/b1_nascimento.png`.
- **O que acontece:** não há tela de título, "Novo jogo/Continuar", nem nenhuma dica de botão na tela. Os ~25 comandos só existem em Pausa > Comandos. A primeira peça (Antena, 54 m a oeste da base) fica fora da primeira vista: a câmera nasce olhando para o norte, e na foto não aparece o facho verde dela. A bússola mostra N, a casinha e uma caveira, e mais nada.
- **Por que incomoda:** um adulto vai descobrir andar e pular; voar exige "pular, e no ar apertar L3", que ninguém adivinha. Uma criança que não lê não descobre nunca. A história (o robô carrega a consciência do Faísca) não é contada no começo: só aparece de leve na memória do Casco, a mais longe da base.
- **Sugestão simples:** (a) nascer olhando para a Antena, com o facho à vista; (b) 4 ou 5 dicas de botão com o ícone do controle, só na primeira vez de cada coisa: andar, pular, "no ar: L3 para voar", "esquentou? mergulhe", "pegue a peça"; (c) o drone voar até a Antena e esperar lá, como quem chama; (d) uma frase ou imagem de abertura sobre o Faísca.

### 2. Botões sobrecarregados, e o X derruba do voo [código + foto]

- **Onde:** `armadura.gd` linhas 744 a 746 (voo), `controles.gd`.
- **O que acontece:** no voo, **um toque no X corta os jatos e o robô cai** (sem as asas, na hora). O X é o pulo, o botão que criança aperta sem parar. Ao mesmo tempo, segurar o X no ar decola, e o X no ar faz o pulo duplo. Outros acúmulos: L3 corre, liga e corta o voo e acelera o nado; R3 para no ar e, no chão, é a espada; O é esquiva, manobra no voo e descer na água; no teclado o Shift corre, liga o voo e (segurado) troca para o planador.
- **Por que incomoda:** a mesma mão faz coisas opostas conforme o estado, e o estado nem sempre está claro na tela. A doc mostra que isso já mudou de ideia três vezes (§32: "X no voo não faz nada"; §33; §65: "toque corta tudo"). Para criança, cair do céu ao apertar "pular" é frustrante e parece defeito.
- **Sugestão simples:** no voo, X não corta nada (deixa cortar só no L3, ou faz o X dar um impulso para cima). Para quem tem filhos pequenos, um "modo fácil" nos ajustes: voo liga sozinho ao segurar o pulo e só desliga ao pousar.

### 3. Tabela de comandos e dicas da pausa estão erradas [código + foto]

- **Onde:** `pausa.gd` (`COMANDOS` e `DICAS`); foto `tester_menus/n7_comandos.png`.
- **O que está errado:**
  - "Parar no ar · frear: L2 · O" e no teclado "F · C": desde a §88 o O/C no voo é a **manobra** (giro); a freada saiu. Quem seguir a tabela vai girar em vez de frear.
  - Dica "Mirando, o tiro trava na máquina mais perto da mira": a trava virou a "Mira assistida", fabricável na oficina (§66). Sem ela, não trava.
- **Por que incomoda:** a única ajuda do jogo ensina errado.
- **Sugestão simples:** corrigir as duas linhas; no futuro, gerar a tabela a partir do mesmo lugar que liga os botões, para não sair de novo do lugar.

### 4. Sem mapa, sem lista do que falta, e memórias sem sinal [código + foto]

- **Onde:** HUD (`hud.gd`, bússola), pausa, `memorias.gd`, `pecas_mundo.gd`; mapa `docs/mapa/mapa_lugares.jpg`.
- **O que acontece:** são cerca de 30 lugares, 10 peças e 10 memórias numa ilha de 5,6 km² de terra. No jogo há só a bússola. A antena só capta peças a menos de 300 m, e quase todas estão a 560 m ou mais da base. As memórias são um cristal de 0,5 m com luz de 6 m que some aos 90 a 120 m, sem nenhum sinal na bússola, e algumas ficam no meio de lugares compridos (a da Fenda fica a 250 m dentro de um cânion de 470 m; a das Torres, ao pé da torre do meio de cinco espalhadas por 544 m). A oficina diz só "Peça não encontrada · em algum lugar da ilha" (foto `n3_oficina_pecas.png`). Não há na pausa nenhuma página de progresso (quais lugares, quais memórias).
- **Por que incomoda:** na primeira meia hora, explorar sem mapa é gostoso. Depois de uma hora você chegou às Torres, leu o nome na tela e foi embora sem saber que havia uma memória ali. Para achar a 8ª, a 9ª e a 10ª, você não tem nada.
- **Sugestão simples:** (a) uma página "Mapa" na pausa, usando a imagem que o jogo já sabe fazer (`--mapa`), mostrando só os lugares visitados e um ícone de peça e de memória achada ou faltando em cada um; (b) ao chegar num lugar que ainda guarda memória, o drone apita ou a bússola mostra um pontinho âmbar; (c) na oficina, trocar "em algum lugar da ilha" pela região ("perto do Farol").

### 5. Não existe fim [código + dedução]

- **Onde:** `pecas_mundo.gd` (`_pegar`), `memorias.gd`; procurei por qualquer evento de "todas achadas" e não há.
- **O que acontece:** a 10ª peça mostra "10 de 10" no aviso, igual à 3ª. A 10ª memória abre o texto dela e só. O Faísca continua caído na base, a ilha não muda.
- **Por que incomoda:** quem jogou 5 horas atrás das peças e memórias quer uma recompensa. Sem ela, o jogo termina quando a pessoa cansa, e a lembrança que fica é de "acabou do nada".
- **Sugestão simples:** com as 10 memórias lidas, uma cena curta no Faísca caído (ou o Farol Apagado acender à noite, visível da ilha toda) e um texto final. Com as 10 peças, um voo especial (as asas e os bocais juntos) para algum lugar que antes não dava.

### 6. "Sossego" com caveira, mísseis e máquina hostil perto do começo [código + foto]

- **Onde:** bússola (`hud.gd`: a caveira da Fundição aparece sempre, presa na ponta quando fora de vista; foto `b1_nascimento.png`, `h1_andando.png`); `main.gd` põe um mecha hostil em (-62, -56), uns 120 m da base, rio acima, que vê o robô a 42 m; `inimigos.gd`: um mecha grande em (-655, 462), a uns 30 m da peça das Molas na Torre Caída, e outro em (150, 620), perto dos Campos do Sul e do Anel.
- **O que acontece:** o título promete sossego, mas a primeira coisa que a bússola mostra é uma caveira, e a direção mais natural da primeira caminhada (seguir o riacho para o norte) passa perto de uma máquina que atira. A Fundição tem seis armas, granadas, níveis, sucata, núcleos e chips.
- **Por que incomoda:** para adulto que quer luta, a Fundição é um extra legal. Para criança e para quem veio passear, levar três tiros e acordar na base com três horas a menos no dia, longe de onde estava indo, é a maior chance de largar o jogo nos primeiros 10 minutos. [dedução]
- **Sugestão simples:** tirar o mecha de perto da clareira; trocar a caveira por um ícone de forja (e só mostrar depois de a pessoa ver a Fundição); afastar o mecha grande da peça das Molas; nos ajustes, "máquinas: brigam / só na Fundição".

### 7. No chão, o capim cobre tudo [foto]

- **Onde:** fotos `tester_hud/h1_andando.png`, `h2_mirando_quente.png`, `tester_dia/v14_robo_no_capim.png`, `tester_memoria/q04b_cervo.png`, `q06_voo_baixo.png`, `tester_menus/n2_roda.png`.
- **O que acontece:** o capim chega no peito do robô de 1,2 m e a câmera fica dentro dele. Metade de baixo da tela vira folha, folhas passam na frente do robô (`h1`), o cervo da foto `q04b_cervo` é um pontinho marrom quase invisível atrás do capim, e com a roda de armas aberta o robô nem aparece (`n2`). As folhas têm borda escura forte, e o campo de perto vira um padrão listrado que cansa a vista (`tester_dia/v3_lagoa.png`, `v9_capim_de_perto.png`).
- **Por que incomoda:** andar é metade do jogo e é onde os bichos e as peças estão. Se você não vê o chão nem o bicho, o passeio a pé fica sem graça e cansativo.
- **Sugestão simples:** câmera do chão um pouco mais alta e mais longe; capim mais baixo ou mais ralo num raio de poucos metros da câmera (não só em volta do robô); folhas perto da câmera ficarem transparentes, como já fazem as copas; menos contraste na borda escura das folhas.

### 8. A mira e os números somem sobre o verde [foto]

- **Onde:** `tester_hud/h2_mirando_quente.png` (a mira é um traço branco fino quase invisível no meio da tela), `tester_memoria/q07_do_alto.png` ("123 m" em cinza claro), `tester_hud/h4_superaquecido.png` ("65 km/h · m do chão" ilegível sobre a mata escura).
- **Por que incomoda:** mirar numa máquina sem ver a mira é frustrante; a velocidade e a altura só servem se dá para ler.
- **Sugestão simples:** contorno escuro (ou sombra) na mira e nos números, como já foi feito no contador de munição (§90).

### 9. A ilha tem muito chão vazio e repetido [foto + dedução]

- **Onde:** `docs/mapa/mapa_lugares.jpg`, `docs/visual/luz_e_cor_resto_do_mapa.jpg`, `tester_dia/v7_voo_alto.png`, `v10_mata_por_dentro.png`.
- **O que acontece:** entre os marcos há faixas enormes de campo verde-limão plano: o sudoeste entre a Torre Caída e a Fenda, o sul em volta do Anel, o leste entre o Platô e as Encostas do Dique, o noroeste entre o Observatório e a costa. As árvores são espalhadas por igual, como pontilhado, sem bosques, clareiras ou trilhas naturais que façam formas. As costas oeste e norte são retas, e a ilha ainda parece quadrada de cima. Dez dos lugares só têm um cristal; nenhum tem algo para fazer no ar (a "diversão no ar" ficou para o fim, doc §41).
- **Conta de jogador:** no cruzeiro (65 km/h) atravessar 500 m de campo vazio leva quase 30 s; da base ao Farol são 1,9 km, quase 2 minutos, com uma parada para esfriar. Se nesse caminho não há nada, o voo vira transporte. [dedução]
- **Sugestão simples:** coisas pequenas e baratas a cada 150 a 250 m: um ninho, uma pedra com formato, um bicho raro, um robô pequeno caído, uma flor diferente que dá para "colecionar" com o scanner, anéis de vento ou correntes de ar quente que dão velocidade ou esfriam, desafios curtos (passar dentro do Anel, voar por baixo da represa). E agrupar as árvores em manchas com clareiras.

### 10. O visual tem dois estilos que brigam [foto]

- **Onde:** `docs/vale/marcos_oeste.jpg`, `marcos_leste.jpg`, `ideias_2026_11_18.jpg` (o navio), `tester_dia/v7_voo_alto.png`, `tester_memoria/q07_do_alto.png`.
- **O que acontece:**
  - As árvores e plantas são de pacote, bem acabadas; o navio, o observatório, a represa e o cais são caixas lisas de cor chapada. Lado a lado, parecem de jogos diferentes.
  - **O rio visto do alto parece estrada de paralelepípedo** (cinza, com textura de pedra; `q07_do_alto.png`, `v7_voo_alto.png`), justo num vale "sem estradas".
  - O desfoque do fundo é forte (`v7_voo_alto.png`): a ilha parece maquete em miniatura.
  - O verde-limão dos campos abertos é muito saturado (`v4_campo_aberto.png`, `v10_mata_por_dentro.png`).
  - As pedras grandes têm faces lisas e escuras de baixo polígono (`q05_mirante.png`), que destoam do capim fofo.
- **Sugestão simples:** água do rio mais azul ou verde e mais clara, com brilho; desfoque mais fraco ou só quando parado; campo com mais variação (manchas secas, flores, tons de verde); uma camada de musgo, trepadeira e ferrugem nas construções de caixa.

### 11. Textos pequenos e só para quem lê [foto + código]

- **Onde:** memórias (foto `docs/vale/ideias_2026_11_18.jpg`: "X, círculo ou Esc para fechar" minúsculo; o texto corre em letra pequena num fundo escuro), avisos "Peça encontrada... pouse: o drone vem instalar", convites "Quadrado / E: entrar na oficina" (foto `n6_pausa.png`).
- **O que acontece:** toda informação importante é texto. Os convites misturam os dois jeitos de jogar ("Quadrado / E") em vez de mostrar só o que está em uso. Não há narração nas memórias.
- **Por que incomoda:** o público inclui criança que não lê. Para ela, a memória é uma tela escura com letras, e o aviso da peça é um texto que passa.
- **Sugestão simples:** ícone do botão (o desenho do quadrado do DualSense) em vez da palavra; mostrar só o botão do aparelho em uso; uma figura em cada memória (um desenho simples do lugar como era) e, se der, a voz de alguém da família lendo.

### 12. A bússola confunde [foto]

- **Onde:** `b1_nascimento.png`, `q05_mirante.png`, `h1_andando.png`.
- **O que acontece:** fora do campo de 120°, a caveira e a casinha ficam presas na ponta da faixa. A caveira passa o tempo todo grudada na ponta esquerda, e parece que a Fundição está sempre ali. A faixa é cinza clara e some sobre nuvem branca, e o "N" e o "O" ficam quase invisíveis (`h1`, `b1`).
- **Sugestão simples:** quando o ícone está fora do campo, uma setinha na ponta em vez do ícone inteiro; faixa um pouco mais escura.

### 13. O progresso não guarda onde você estava [código]

- **Onde:** `main.gd` (`_retomar_progresso`: só a hora e os lugares; a posição não é salva).
- **O que acontece:** saiu do jogo perto do Farol, volta na base, a 1,9 km. Não há "Novo jogo": apagar o progresso fica escondido nos Ajustes.
- **Sugestão simples:** guardar a última posição em chão firme; na abertura, "Continuar / Novo jogo".

### 14. Som: só há música nas memórias [código + dedução]

- **Onde:** `assets/sons/`, `memorias.gd` (único lugar com música).
- **O que acontece:** passeio, voo e noite são só ambiente e motor. Num jogo de passear, uma música leve que entra ao chegar num lugar novo, ao amanhecer ou num voo alto faz muita diferença. Não ouvi nada; é leitura dos arquivos.
- **Sugestão simples:** três ou quatro faixas curtas que tocam de vez em quando (chegada a lugar novo, nascer do sol, voo alto), com silêncio entre elas.

### 15. Pequenos

- O aviso de peça instalada passa por baixo da roda de armas e fica cortado (`n2_roda.png`). [foto]
- O drone colega nasce enorme, cortado na borda esquerda da primeira vista (`b1_nascimento.png`). Ele é simpático, mas assim parece um objeto atrapalhando. [foto]
- Superaquecer é mostrado por um arco vermelho pequeno embaixo (`h4_superaquecido.png`), e o texto "MOTOR SUPERAQUECIDO" saiu (§72). Quem estiver olhando a paisagem só percebe quando cai. O alarme sonoro ajuda, mas não ouvi. [foto + dedução]
- A pane avança 3 horas do dia (`Ajustes.PANE_HORAS`): de tarde, uma pane vira noite, e quem estava indo ver algo de dia perde a viagem. [código]
- De noite o verde fica chapado, tudo no mesmo tom esverdeado (`tester_noite/v4_campo_aberto.png`); um pouco de azul no céu e nas sombras, e mais vaga-lumes perto da água, dariam mais vida. [foto]
- **Para quem mantém as fotos (não é problema de jogador):** a vista `v6_voo_baixo` do `--visual` sai com a câmera **debaixo do chão**: aparecem troncos "pendurados" e a água por baixo (`tester_dia/v6_voo_baixo.png`, `tester_chuva/v6_voo_baixo.png`). A altura dessa vista é fixa e o relevo de 3 km mudou ali. É a mesma cara que o jogo teria se a câmera de verdade atravessasse o chão; vale conferir que isso não acontece em ladeira íngreme. [foto + dedução]

---

## O que não deu para verificar

- **Sensação de controle:** peso do robô, curva no voo, giro de caça, nado, decolagem segurando o X, trancos da câmera. Só se sente na mão.
- **Som:** nada foi ouvido (passos, motor, alarme, drone, música das memórias, mixagem).
- **Vibração do DualSense** e o L3/R3 em mãos pequenas.
- **Desempenho:** não medi de propósito (é do game dev). As fotos imprimem fps, mas a máquina estava rodando outros três Godot ao mesmo tempo.
- **Dificuldade real das máquinas e da Fundição:** só li os números (3 acertos, 42 m de visão, aviso de 0,65 s antes do tiro).
- **A tela de memória rodando:** a chave `--memoria` só funciona junto com `--largo` e minha rodada caiu nas fotos normais (`tester_memoria/` tem as fotos padrão `q01` a `q07`, às 17h); usei a foto pronta da doc.
- **Chuva em voo** e debaixo d'água: vi só a chuva no chão (`tester_chuva/`) e as fotos submarinas da doc.
- **Tempos reais** de achar cada peça e cada memória, e se a pessoa se perde: é dedução a partir das distâncias do código.
- **O que o jogo mostra na primeira abertura de verdade** (com save novo): as fotos rodam em modo de captura, e a ordem exata do que aparece primeiro saiu do código.

---

## As 5 mudanças que eu pediria primeiro

1. **Primeiros 5 minutos guiados:** nascer olhando a Antena, o drone indo até ela, dicas de botão com ícone na primeira vez de cada ação (pular, voar no ar, esfriar na água, pegar a peça), e uma frase de abertura sobre o Faísca.
2. **Tirar o X do corte do voo** (e conferir a tabela de comandos e as dicas da pausa, que hoje ensinam errado a freada e a trava).
3. **Mapa e progresso na pausa:** lugares visitados, peças e memórias achadas e faltando por lugar, e algum sinal da memória ao chegar num lugar que ainda guarda uma.
4. **Um fim:** cena curta ao ler as 10 memórias (o Faísca, ou o Farol acendendo) e algo novo ao ter as 10 peças.
5. **Câmera e capim no chão:** câmera mais alta, capim que abre também perto da câmera, mira e números com contorno. Junto, tirar o mecha hostil de perto da clareira e trocar a caveira da bússola.

---

## Observação sobre as minhas fotos

Uma rodada minha saiu sem as chaves certas (o terminal juntou todas as chaves numa palavra só) e o jogo gravou as fotos padrão `q01` a `q07` na pasta `tools/capturas/vale/` (que é ignorada pelo git), por cima das que estavam lá com o mesmo nome. São as mesmas fotos que o jogo tira por padrão, só refeitas hoje. Depois refiz tudo nas pastas `tester_*`.
