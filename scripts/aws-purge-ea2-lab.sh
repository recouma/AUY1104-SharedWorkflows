#!/usr/bin/env bash
# Borra recursos típicos del módulo infra/ea2-sandbox-vm sin terraform state.
# Criterios: tag Purpose=AUY1104-EA2-lab en EC2; nombres ea2-lab-sg-* / ea2-lab-* en SG y key pairs.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
DRY_RUN="${DRY_RUN:-true}"

log() { printf '%s\n' "$*"; }

run_aws() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

collect_instance_ids() {
  local a b
  a=$(aws ec2 describe-instances --region "$REGION" \
    --filters \
      "Name=tag:Purpose,Values=AUY1104-EA2-lab" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | tr '\t' '\n' || true)
  b=$(aws ec2 describe-instances --region "$REGION" \
    --filters \
      "Name=tag:Name,Values=ea2-k8s-sandbox" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | tr '\t' '\n' || true)
  printf '%s\n%s\n' "$a" "$b" | sed '/^$/d' | sort -u
}

terminate_instances() {
  local ids_raw ids
  ids_raw=$(collect_instance_ids)
  ids=$(echo "$ids_raw" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if [[ -z "${ids// }" ]]; then
    log "EC2: no hay instancias candidatas (tag Purpose=AUY1104-EA2-lab o Name=ea2-k8s-sandbox)."
    return 0
  fi
  log "EC2 a terminar: $ids"
  run_aws aws ec2 terminate-instances --region "$REGION" --instance-ids $ids
  if [[ "$DRY_RUN" != "true" ]]; then
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids $ids
    log "EC2: terminadas."
  fi
}

delete_security_groups() {
  local sgs
  sgs=$(aws ec2 describe-security-groups --region "$REGION" \
    --query "SecurityGroups[?starts_with(GroupName, \`ea2-lab-sg-\`)].GroupId" --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d' || true)
  if [[ -z "$sgs" ]]; then
    log "Security groups ea2-lab-sg-*: ninguno."
    return 0
  fi
  local sg
  while IFS= read -r sg; do
    [[ -z "$sg" ]] && continue
    log "Eliminar security group: $sg"
    run_aws aws ec2 delete-security-group --region "$REGION" --group-id "$sg"
  done <<< "$sgs"
}

delete_key_pairs() {
  local keys
  keys=$(aws ec2 describe-key-pairs --region "$REGION" \
    --query "KeyPairs[?starts_with(KeyName, \`ea2-lab-\`)].KeyName" --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d' || true)
  if [[ -z "$keys" ]]; then
    log "Key pairs ea2-lab-*: ninguno."
    return 0
  fi
  local kn
  while IFS= read -r kn; do
    [[ -z "$kn" ]] && continue
    log "Eliminar key pair: $kn"
    run_aws aws ec2 delete-key-pair --region "$REGION" --key-name "$kn"
  done <<< "$keys"
}

log "Región: $REGION | DRY_RUN=$DRY_RUN"
terminate_instances
# Tras borrar la VM, los SG suelen poder borrarse; si falla por ENI, re-ejecutar una vez.
delete_security_groups
delete_key_pairs
log "Listo."
