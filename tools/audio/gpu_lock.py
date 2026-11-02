"""Trava global da GPU entre processos (vários agentes gerando áudio ao mesmo tempo).

Por que existe: o Stable Audio Open no diffusers ocupa ~8–12 GB por lote (gera
sempre o bloco latente de 47 s). Dois geradores juntos nos 16 GB da RTX 4070 Ti
SUPER fazem o Windows transbordar pra RAM e TODOS ficam 2–3x mais lentos (medido:
13 → 30 s por som). Revezar lotes pequenos é mais rápido pra todo mundo do que
dividir a placa.

Uso (cada CHAMADA ao modelo pega a trava, gera um lote pequeno e solta — assim
nenhum agente segura a GPU por meia hora):

    from gpu_lock import gpu_lock
    with gpu_lock("sfx_pilot ui_clique"):
        out = pipe(...)

Implementação: `msvcrt.locking` num byte do arquivo C:/Users/gabri/ai_audio/gpu.lock
(trava do próprio Windows: some sozinha se o processo morrer, sem trava órfã).
Sem dependência extra. Quem está segurando fica escrito em gpu.lock.owner, só
pra diagnóstico.
"""
from __future__ import annotations

import contextlib
import os
import time
from pathlib import Path

LOCK_PATH = Path("C:/Users/gabri/ai_audio/gpu.lock")
OWNER_PATH = LOCK_PATH.with_suffix(".lock.owner")
QUEUE_DIR = LOCK_PATH.parent / "gpu_queue"


@contextlib.contextmanager
def gpu_lock(label: str = "", timeout_s: float | None = None, poll_s: float = 0.5, verbose: bool = True):
    """Espera a GPU ficar livre e a segura durante o bloco `with`.

    `timeout_s=None` espera para sempre (o normal: o outro lote termina em
    1–3 min). Com timeout, levanta TimeoutError.
    """
    import msvcrt
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    fd = os.open(str(LOCK_PATH), os.O_RDWR | os.O_CREAT)
    t0 = time.monotonic()
    warned = False
    # Fila por ticket: sem ela, quem acabou de soltar repega a trava no mesmo instante e quem
    # espera por polling quase nunca entra (o agente B ficou 10 min na fila). Só tenta a trava
    # quem tem o ticket mais antigo; quem solta e volta entra no fim da fila.
    ticket = QUEUE_DIR / f"{time.time():.6f}_{os.getpid()}_{id(fd)}.t"
    ticket.write_text(label, encoding="utf-8")
    try:
        while True:
            try:
                os.utime(ticket)  # prova de vida: ticket parado há >10 s é de processo morto
                if not _is_first(ticket):
                    raise OSError("não é a vez")
                os.lseek(fd, 0, os.SEEK_SET)
                msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
                with contextlib.suppress(OSError):
                    ticket.unlink()
                break
            except OSError:
                if timeout_s is not None and time.monotonic() - t0 > timeout_s:
                    raise TimeoutError(f"GPU ocupada há mais de {timeout_s:.0f} s ({_owner()})")
                if verbose and not warned:
                    print(f"[gpu_lock] esperando GPU ({_owner()})", flush=True)
                    warned = True
                time.sleep(poll_s)
        waited = time.monotonic() - t0
        if verbose and waited > 1.0:
            print(f"[gpu_lock] GPU liberada após {waited:.0f} s", flush=True)
        with contextlib.suppress(OSError):
            OWNER_PATH.write_text(f"pid {os.getpid()} · {label} · desde {time.strftime('%H:%M:%S')}",
                                  encoding="utf-8")
        try:
            yield
        finally:
            with contextlib.suppress(OSError):
                OWNER_PATH.write_text("", encoding="utf-8")
            os.lseek(fd, 0, os.SEEK_SET)
            with contextlib.suppress(OSError):
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
    finally:
        with contextlib.suppress(OSError):
            ticket.unlink()
        os.close(fd)


def _is_first(ticket: Path) -> bool:
    """Meu ticket é o mais antigo entre os vivos? Tickets sem `utime` há >10 s são de quem morreu."""
    now = time.time()
    alive = []
    for t in QUEUE_DIR.glob("*.t"):
        try:
            if now - t.stat().st_mtime > 10.0 and t != ticket:
                t.unlink()
                continue
        except OSError:
            continue
        alive.append(t.name)
    alive.sort()
    return not alive or alive[0] == ticket.name


def _owner() -> str:
    try:
        return OWNER_PATH.read_text(encoding="utf-8").strip() or "dono desconhecido"
    except OSError:
        return "dono desconhecido"


if __name__ == "__main__":
    # Teste rápido: `python gpu_lock.py` em dois terminais — o segundo espera.
    with gpu_lock("teste manual"):
        print("trava adquirida; segurando 5 s")
        time.sleep(5)
    print("solta")
