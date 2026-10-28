# Atividade 2 - Airsoft: Circuito de Precisão

- **Motor:** Godot 4.2 ou superior (projeto criado para 4.x, renderer Compatibility)
- **Linguagem:** GDScript
- **Integrantes:** (preencher)
- **Como rodar:** Godot -> Importar -> `project.godot` -> F5. O Console é o painel "Saída".

## Controles
| Ação | Comando |
|---|---|
| Andar / mirar | WASD / mouse |
| Atirar | botão esquerdo (SEMI: 1 por clique; AUTO: segurando) |
| Alternar SEMI/AUTO | F |
| Hop-up | roda do mouse (limites 0 a 6, passo 0,25) |
| Pegar carregador | E (perto dele) |
| Mola menos/mais forte | Z / X |
| Pausar | Esc |

## Objetivo e progressão
Acertar todos os alvos de cada etapa antes do tempo acabar (3 etapas). Pontos: 100/75/50 conforme o aro atingido, mais bônus de 10 pontos por segundo restante.
Derrota: tempo esgotado ou sem munição e sem carregador compatível utilizável no cenário.

| Etapa | Alvos | Raio | Distância | Tempo | Movimento |
|---|---|---|---|---|---|
| 1 | 5 | 0,50 m | 10-16 m | 60 s | parados |
| 2 | 6 | 0,25 m | 18-35 m | 55 s | parados |
| 3 | 6 | 0,35 m | 15-30 m | 50 s | 1,5 m/s lateral |

Cada etapa também muda os carregadores espalhados (massas 0,20 / 0,25 / 0,32 g). BBs mais pesadas precisam de mais Hop-up, mas mantêm mais velocidade a longa distância.

## Decisões de modelagem
- `types.gd`: **único** enum `MagType {Shotgun, Rifle, Pistol1911, PistolGlock}`, usado por arma e carregador (nunca se compara texto).
- `magazine.gd`: objeto independente (tipo, capacidade > 0, munição entre 0 e capacidade, massa em **kg**; gramas só na exibição).
- `weapon.gd`: dona do disparo. Pede quantidade e massa ao carregador equipado. Não conhece HUD nem alvos; só emite sinais.
- `bb.gd`: continua dona da própria física (Atividade 1): gravidade, arrasto quadrático e sustentação `sqrt(v) * BackspinDrag`.
- `hud.gd`: só apresenta. Atualiza por sinais (sem buscar nós a cada frame).
- `game_manager.gd`: etapas, tempo, pontuação, vitória/derrota.
- **Mola (modelo físico):** `E = ½·k·x²` com k = 2000 N/m e x = 38,6 mm (E ≈ 1,49 J). Velocidade recalculada a cada tiro: `v = sqrt(2E/m)`.
- **Cadência:** `ROF = RPM / (60·N)` e `intervalo = 1/ROF`. Padrão: 9000 RPM, N = 30, ROF = 5 BB/s (0,200 s). O ROF aparece no HUD e no Console.
- **Troca de carregador (melhoria):** o carregador antigo fica no cenário, no lugar da troca.
- O scroll só ajusta o Hop-up com o mouse capturado e o jogo ativo (não em menu/pausa/fim de partida).
