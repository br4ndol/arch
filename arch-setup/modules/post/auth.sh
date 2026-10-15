#!/usr/bin/env bash
# desc: sudo con asteriscos (pwfeedback) y faillock: 10 intentos, 5 min de bloqueo

module_run() {
  log_step "sudo: pwfeedback"
  write_file /etc/sudoers.d/pwfeedback 440 <<<'Defaults pwfeedback'
  if ! ((DRY_RUN)) && ! visudo -cqf /etc/sudoers.d/pwfeedback; then
    rm -f /etc/sudoers.d/pwfeedback
    die "sudoers.d/pwfeedback no era válido; se ha quitado"
  fi

  log_step "faillock"
  set_kv /etc/security/faillock.conf deny 10
  set_kv /etc/security/faillock.conf unlock_time 300
}
