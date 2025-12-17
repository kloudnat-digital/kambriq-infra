#!/usr/bin/env node

/**
 * Script pour mettre à jour automatiquement CONTEXTE_WORKSPACE.md
 * Détecte les changements dans les workflows, scripts, et autres fichiers importants
 * et met à jour la date et les sections pertinentes.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CONTEXTE_FILE = path.join(__dirname, '../docs/architecture/CONTEXTE_WORKSPACE.md');
const WORKSPACE_ROOT = path.join(__dirname, '../../');

// Couleurs pour les messages
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Obtenir la date actuelle au format YYYY-MM-DD
function getCurrentDate() {
  return new Date().toISOString().split('T')[0];
}

// Détecter les fichiers modifiés dans le commit (repo actuel)
function getModifiedFilesInRepo(repoPath) {
  try {
    // Fichiers stagés
    const staged = execSync('git diff --cached --name-only --diff-filter=ACM', {
      encoding: 'utf-8',
      cwd: repoPath,
      stdio: 'pipe'
    }).trim().split('\n').filter(Boolean);
    
    // Fichiers modifiés mais non stagés
    const unstaged = execSync('git diff --name-only --diff-filter=ACM', {
      encoding: 'utf-8',
      cwd: repoPath,
      stdio: 'pipe'
    }).trim().split('\n').filter(Boolean);
    
    return [...new Set([...staged, ...unstaged])];
  } catch (error) {
    return [];
  }
}

// Détecter les fichiers modifiés dans les deux repos
function getModifiedFiles() {
  const terraformRepo = path.join(__dirname, '..');
  const appRepo = path.join(WORKSPACE_ROOT, 'kambriq');
  
  const terraformFiles = getModifiedFilesInRepo(terraformRepo).map(f => `terraform:${f}`);
  const appFiles = getModifiedFilesInRepo(appRepo).map(f => `app:${f}`);
  
  return [...terraformFiles, ...appFiles];
}

// Vérifier si des workflows ont été modifiés
function hasWorkflowChanges(files) {
  return files.some(file => {
    const cleanFile = file.replace(/^(terraform|app):/, '');
    return cleanFile.includes('.github/workflows/') && cleanFile.endsWith('.yml');
  });
}

// Vérifier si des scripts ont été modifiés
function hasScriptChanges(files) {
  return files.some(file => {
    const cleanFile = file.replace(/^(terraform|app):/, '');
    return cleanFile.includes('scripts/') && (cleanFile.endsWith('.sh') || cleanFile.endsWith('.js'));
  });
}

// Vérifier si des modules Terraform ont été modifiés
function hasTerraformChanges(files) {
  return files.some(file => {
    const cleanFile = file.replace(/^(terraform|app):/, '');
    return cleanFile.includes('modules/') || cleanFile.includes('envs/') && 
           (cleanFile.endsWith('.tf') || cleanFile.endsWith('.tfvars'));
  });
}

// Vérifier si des fichiers applicatifs ont été modifiés
function hasAppChanges(files) {
  return files.some(file => {
    const cleanFile = file.replace(/^(terraform|app):/, '');
    return file.startsWith('app:') && (
      cleanFile.includes('api/') || 
      cleanFile.includes('web/') ||
      cleanFile.includes('package.json') ||
      cleanFile.includes('Dockerfile')
    );
  });
}

// Lire le fichier CONTEXTE_WORKSPACE.md
function readContexteFile() {
  try {
    return fs.readFileSync(CONTEXTE_FILE, 'utf-8');
  } catch (error) {
    log(`❌ Erreur lors de la lecture de ${CONTEXTE_FILE}`, 'red');
    return null;
  }
}

// Mettre à jour la date de dernière mise à jour
function updateLastModifiedDate(content) {
  const currentDate = getCurrentDate();
  const datePattern = /\*\*Dernière mise à jour :\*\* \d{4}-\d{2}-\d{2}/;
  
  if (datePattern.test(content)) {
    return content.replace(datePattern, `**Dernière mise à jour :** ${currentDate}`);
  }
  
  return content;
}

// Mettre à jour les références aux workflows
function updateWorkflowReferences(content) {
  // Remplacer les anciennes références par les optimisées
  const replacements = [
    { old: /terraform-dev\.yml/g, new: 'terraform-dev-optimized.yml' },
    { old: /terraform-prod\.yml/g, new: 'terraform-prod-optimized.yml' },
    { old: /deploy-app-dev\.yml/g, new: 'deploy-app-dev-optimized.yml' },
    { old: /deploy-app-prod\.yml/g, new: 'deploy-app-prod-optimized.yml' },
  ];
  
  let updated = content;
  for (const { old, new: newValue } of replacements) {
    updated = updated.replace(old, newValue);
  }
  
  return updated;
}

// Vérifier et corriger les sections dupliquées
function removeDuplicateSections(content) {
  // Supprimer les sections dupliquées de deploy-app-dev-optimized.yml
  const lines = content.split('\n');
  const result = [];
  let inDuplicateSection = false;
  let duplicateStartIndex = -1;
  let foundFirstSection = false;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Détecter le début d'une section deploy-app-dev-optimized.yml
    if (line.includes('#### `deploy-app-dev-optimized.yml`')) {
      if (foundFirstSection) {
        // C'est une section dupliquée, on la marque pour suppression
        inDuplicateSection = true;
        duplicateStartIndex = i;
        continue;
      } else {
        foundFirstSection = true;
      }
    }
    
    // Détecter la fin d'une section (début d'une nouvelle section ou fin du document)
    if (inDuplicateSection && (line.startsWith('####') || line.startsWith('###') || line.startsWith('##'))) {
      inDuplicateSection = false;
      duplicateStartIndex = -1;
    }
    
    // Ajouter la ligne si elle n'est pas dans une section dupliquée
    if (!inDuplicateSection) {
      result.push(line);
    }
  }
  
  return result.join('\n');
}

// Fonction principale
function main() {
  log('\n🔄 Mise à jour automatique de CONTEXTE_WORKSPACE.md', 'blue');
  log('═'.repeat(60), 'blue');
  
  const files = getModifiedFiles();
  log(`\n📝 Fichiers modifiés détectés: ${files.length}`, 'cyan');
  
  if (files.length === 0) {
    log('  ℹ️  Aucun fichier modifié, pas de mise à jour nécessaire', 'yellow');
    return;
  }
  
  // Vérifier les types de changements
  const hasWorkflow = hasWorkflowChanges(files);
  const hasScript = hasScriptChanges(files);
  const hasTerraform = hasTerraformChanges(files);
  const hasApp = hasAppChanges(files);
  
  if (!hasWorkflow && !hasScript && !hasTerraform && !hasApp) {
    log('  ℹ️  Aucun changement dans workflows/scripts/Terraform/app, pas de mise à jour nécessaire', 'yellow');
    return;
  }
  
  log(`\n🔍 Changements détectés:`, 'cyan');
  if (hasWorkflow) log('   ✅ Workflows GitHub Actions', 'green');
  if (hasScript) log('   ✅ Scripts', 'green');
  if (hasTerraform) log('   ✅ Modules/Environnements Terraform', 'green');
  if (hasApp) log('   ✅ Code applicatif (API/Web)', 'green');
  
  // Lire le fichier
  let content = readContexteFile();
  if (!content) {
    log('❌ Impossible de lire le fichier CONTEXTE_WORKSPACE.md', 'red');
    process.exit(1);
  }
  
  // Mettre à jour
  log('\n📝 Mise à jour en cours...', 'yellow');
  
  // Mettre à jour la date
  content = updateLastModifiedDate(content);
  log('   ✅ Date de dernière mise à jour', 'green');
  
  // Mettre à jour les références aux workflows
  const beforeWorkflowUpdate = content;
  content = updateWorkflowReferences(content);
  if (content !== beforeWorkflowUpdate) {
    log('   ✅ Références aux workflows', 'green');
  }
  
  // Supprimer les sections dupliquées
  const beforeDedup = content;
  content = removeDuplicateSections(content);
  if (content !== beforeDedup) {
    log('   ✅ Sections dupliquées supprimées', 'green');
  }
  
  // Écrire le fichier mis à jour
  try {
    fs.writeFileSync(CONTEXTE_FILE, content, 'utf-8');
    log('\n✅ CONTEXTE_WORKSPACE.md mis à jour avec succès !', 'green');
    
    // Ajouter le fichier au staging si on est dans un commit
    try {
      execSync(`git add "${CONTEXTE_FILE}"`, {
        cwd: path.join(__dirname, '..'),
        stdio: 'pipe'
      });
      log('   📦 Fichier ajouté au staging automatiquement', 'cyan');
    } catch (error) {
      // Ignorer si on n'est pas dans un repo git ou si le fichier n'est pas modifié
    }
  } catch (error) {
    log(`❌ Erreur lors de l'écriture de ${CONTEXTE_FILE}`, 'red');
    log(`   ${error.message}`, 'red');
    process.exit(1);
  }
  
  log('\n' + '═'.repeat(60), 'blue');
}

main();
