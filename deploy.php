<?php declare(strict_types=1);

namespace Deployer;

require_once 'recipe/common.php';
require_once 'contrib/cachetool.php';

set('bin/console', '{{bin/php}} {{release_or_current_path}}/bin/console');

set('cachetool', '/var/run/php8.3-fpm-holz-leute.de.sock');
set('application', 'Shopware 6');
set('allow_anonymous_stats', false);
set('default_timeout', 3600); // Increase when tasks take longer than that.

import('inventory.yaml');

// These files are shared among all releases.
set('shared_files', [
    '.env.local',
    'install.lock',
    'public/.htaccess',
]);

// These directories are shared among all releases.
set('shared_dirs', [
    'config/jwt',
    'config/packages/prod',
    'files',
    'var/log',
    'public/media',
    'public/thumbnail',
    'public/sitemap',
    'public/images',
]);

// These directories are made writable (the definition of "writable" requires attention).
// Please note that the files in `config/jwt/*` receive special attention in the `sw:writable:jwt` task.
set('writable_dirs', [
    'config/jwt',
    'custom/plugins',
    'files',
    'public/bundles',
    'public/css',
    'public/fonts',
    'public/js',
    'public/media',
    'public/sitemap',
    'public/theme',
    'public/thumbnail',
    'var',
]);

task('sw:deployment:helper', static function (): void {
    run('cd {{release_path}} && vendor/bin/shopware-deployment-helper run');
});

task('sw:touch_install_lock', static function (): void {
    run('cd {{release_path}} && touch install.lock');
});

task('sw:health_checks', static function (): void {
    run('cd {{release_path}} && bin/console system:check --context=pre_rollout');
});

desc('Deploys your project');
task('deploy', [
    'deploy:prepare',
    'deploy:clear_paths',
    'sw:deployment:helper',
    'sw:touch_install_lock',
    'sw:health_checks',
    'deploy:publish',
]);

task('deploy:update_code')->setCallback(static function (): void {
    upload('.', '{{release_path}}', [
        'options' => [
            '--exclude=.git',
            '--exclude=.github',
            '--exclude=deploy.php',
            '--exclude=node_modules',
        ],
        'flags' => '-az',
    ]);
});

// Hooks

after('deploy:failed', 'deploy:unlock');
after('deploy:symlink', 'cachetool:clear:opcache');
