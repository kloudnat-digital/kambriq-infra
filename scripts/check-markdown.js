#!/usr/bin/env node

/**
 * Script de vérification des fichiers Markdown pour kambriq-aws-iac-terraform
 * Vérifie que les fichiers markdown ne contiennent pas de références obsolètes
 * et que les workflows mentionnés existent réellement.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

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

// Patterns obsolètes à détecter
const OBSOLETE_PATTERNS = [
  {
    // NOTE: We intentionally match the *deprecated Terraform variable names* in lowercase.
    // Do NOT use case-insensitive matching here, otherwise we would incorrectly flag
    // environment variables like `ARTIFACT_BUCKET_NAME`.
    pattern: /api_bundle_s3_key|web_bundle_s3_key|ssr_bundle_s3_key|artifact_bucket_name/g,
    message: 'Référence aux variables Terraform d\'artefacts applicatifs (obsolètes depuis 2025-12-07)',
    context: 'Les variables artifact_bucket_name, api_bundle_s3_key, ssr_bundle_s3_key ont été supprimées. Les déploiements applicatifs sont gérés par deploy-app-dev.yml et deploy-app-prod.yml dans le repo kambriq.',
    allowedIn: ['CHANGELOG.md', 'CLEANUP_SUMMARY.md', 'AUDIT_WORKFLOWS.md'], // Permis dans CHANGELOG et docs historiques
    allowedContext: ['REMOVED', 'removed', 'supprimé', 'obsolète', 'obsolete', 'no longer', 'plus utilisé', 'deprecated', 'DEPRECATED', 'historique', 'legacy', 'LEGACY', 'Migration', 'migration'], // Permis si dans un contexte de documentation historique ou migration
  },
  {
    pattern: /static export|build:static|pnpm export/gi,
    message: 'Référence aux méthodes obsolètes static export (remplacé par OpenNext)',
    allowedIn: ['CHANGELOG.md', 'CLEANUP_SUMMARY.md'], // Permis pour documentation historique
    allowedContext: ['Migration', 'migration', 'Migration de', 'remplacé', 'remplacé par', '⚠️ Migration', '⚠️ Migration récente', 'no longer used', 'is no longer used', 'instead of', 'Legacy', 'LEGACY'], // Permis si dans un contexte de migration ou legacy
  },
];

// Workflows qui doivent exister
const REQUIRED_WORKFLOWS = [
  '.github/workflows/terraform-dev-optimized.yml',
  '.github/workflows/terraform-prod-optimized.yml',
  '.github/workflows/terraform-shared.yml',
];

function getModifiedMarkdownFiles() {
  try {
    const staged = execSync('git diff --cached --name-only --diff-filter=ACM', {
      encoding: 'utf-8'
    }).trim().split('\n').filter(Boolean);
    
    const unstaged = execSync('git diff --name-only --diff-filter=ACM', {
      encoding: 'utf-8'
    }).trim().split('\n').filter(Boolean);
    
    const allModified = [...new Set([...staged, ...unstaged])];
    return allModified.filter(file => file.endsWith('.md'));
  } catch (error) {
    return [];
  }
}

function getAllMarkdownFiles() {
  const files = [];
  const repoRoot = process.cwd();
  
  function walkDir(dir, baseDir = repoRoot) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      const relativePath = path.relative(baseDir, fullPath);
      
      // Ignorer .git, .terraform, etc.
      if (entry.name.startsWith('.') && entry.name !== '.github') continue;
      if (entry.name === 'node_modules' || entry.name === '.terraform') continue;
      
      if (entry.isDirectory()) {
        walkDir(fullPath, baseDir);
      } else if (entry.isFile() && entry.name.endsWith('.md')) {
        files.push(relativePath);
      }
    }
  }
  
  walkDir(repoRoot);
  return files;
}

function checkFile(filePath) {
  const errors = [];
  const warnings = [];
  
  if (!fs.existsSync(filePath)) {
    return { errors: [`Fichier introuvable: ${filePath}`], warnings: [] };
  }
  
  const content = fs.readFileSync(filePath, 'utf-8');
  const fileName = path.basename(filePath);
  
  // Vérifier les patterns obsolètes
  for (const { pattern, message, allowedIn, context, allowedContext } of OBSOLETE_PATTERNS) {
    const matches = content.match(pattern);
    if (matches) {
      const isAllowed = allowedIn && allowedIn.some(allowed => fileName.includes(allowed));
      if (!isAllowed) {
        const lines = content.split('\n');
        const lineNumbers = [];
        lines.forEach((line, index) => {
          if (pattern.test(line)) {
            // Vérifier si le contexte est autorisé (ligne actuelle, précédente, ou suivante)
            const contextAllowed = allowedContext && allowedContext.some(ctx => {
              const currentLine = line.toLowerCase();
              const prevLine = index > 0 ? lines[index - 1].toLowerCase() : '';
              const nextLine = index < lines.length - 1 ? lines[index + 1].toLowerCase() : '';
              const ctxLower = ctx.toLowerCase();
              return currentLine.includes(ctxLower) || prevLine.includes(ctxLower) || nextLine.includes(ctxLower);
            });
            if (!contextAllowed) {
              lineNumbers.push(index + 1);
            }
          }
        });
        
        if (lineNumbers.length > 0) {
          const issue = {
            message: `${message} (lignes: ${lineNumbers.join(', ')})`,
            context: context || '',
          };
          
          if (fileName === 'CHANGELOG.md' || fileName.includes('CLEANUP')) {
            warnings.push(issue);
          } else {
            errors.push(issue);
          }
        }
      }
    }
  }
  
  // Vérifier que les workflows mentionnés existent
  const workflowMentions = content.match(/\.github\/workflows\/[\w-]+\.yml/gi);
  if (workflowMentions) {
    const uniqueWorkflows = [...new Set(workflowMentions)];
    for (const workflow of uniqueWorkflows) {
      const workflowPath = path.join(process.cwd(), workflow);
      if (!fs.existsSync(workflowPath)) {
        errors.push({
          message: `Workflow mentionné mais introuvable: ${workflow}`,
          context: `Vérifiez que le workflow existe ou supprimez la référence dans ${fileName}`,
        });
      }
    }
  }
  
  return { errors, warnings };
}

function checkWorkflowsExist() {
  const missing = [];
  
  for (const workflow of REQUIRED_WORKFLOWS) {
    const workflowPath = path.join(process.cwd(), workflow);
    if (!fs.existsSync(workflowPath)) {
      missing.push(workflow);
    }
  }
  
  return missing;
}

function main() {
  log('\n📝 Vérification des fichiers Markdown', 'blue');
  log('═'.repeat(60), 'blue');
  
  const modifiedFiles = getModifiedMarkdownFiles();
  const allMarkdownFiles = getAllMarkdownFiles();
  
  // Si des fichiers markdown sont modifiés, vérifier tous les fichiers importants
  const filesToCheck = modifiedFiles.length > 0 
    ? [...new Set([...modifiedFiles, ...allMarkdownFiles.filter(f => 
        f.includes('README.md') || f.includes('CHANGELOG.md') || f.includes('docs/')
      )])]
    : allMarkdownFiles.filter(f => 
        f.includes('README.md') || f.includes('CHANGELOG.md') || f.includes('docs/')
      );
  
  log(`\n📄 Fichiers à vérifier: ${filesToCheck.length}`, 'cyan');
  
  let totalErrors = 0;
  let totalWarnings = 0;
  
  for (const file of filesToCheck) {
    const { errors, warnings } = checkFile(file);
    
    if (errors.length > 0 || warnings.length > 0) {
      log(`\n📄 ${file}`, 'yellow');
      
      if (errors.length > 0) {
        errors.forEach(err => {
          log(`  ❌ ${err.message}`, 'red');
          if (err.context) {
            log(`     ${err.context}`, 'yellow');
          }
        });
        totalErrors += errors.length;
      }
      
      if (warnings.length > 0) {
        warnings.forEach(warn => {
          log(`  ⚠️  ${warn.message}`, 'yellow');
          if (warn.context) {
            log(`     ${warn.context}`, 'yellow');
          }
        });
        totalWarnings += warnings.length;
      }
    }
  }
  
  // Vérifier que les workflows requis existent
  log('\n🔍 Vérification des workflows requis', 'cyan');
  const missingWorkflows = checkWorkflowsExist();
  if (missingWorkflows.length > 0) {
    log('  ❌ Workflows manquants:', 'red');
    missingWorkflows.forEach(wf => log(`     - ${wf}`, 'red'));
    totalErrors += missingWorkflows.length;
  } else {
    log('  ✅ Tous les workflows requis existent', 'green');
  }
  
  log('\n' + '═'.repeat(60), 'blue');
  
  if (totalErrors > 0) {
    log(`\n❌ ${totalErrors} erreur(s) trouvée(s) dans les fichiers Markdown`, 'red');
    log('   Corrigez ces erreurs avant de commit.', 'yellow');
    if (totalWarnings > 0) {
      log(`   ⚠️  ${totalWarnings} avertissement(s) (non bloquant)`, 'yellow');
    }
    process.exit(1);
  } else if (totalWarnings > 0) {
    log(`\n⚠️  ${totalWarnings} avertissement(s) (non bloquant)`, 'yellow');
    log('✅ Aucune erreur critique', 'green');
    process.exit(0);
  } else {
    log('\n✅ Tous les fichiers Markdown sont à jour !', 'green');
    process.exit(0);
  }
}

main();
