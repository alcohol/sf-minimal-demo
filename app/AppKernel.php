<?php declare(strict_types=1);

/*
 * (c) Rob Bast <rob.bast@gmail.com>
 *
 * For the full copyright and license information, please view
 * the LICENSE file that was distributed with this source code.
 */

namespace Paste;

use Symfony\Bundle\DebugBundle\DebugBundle;
use Symfony\Bundle\FrameworkBundle\FrameworkBundle;
use Symfony\Bundle\MonologBundle\MonologBundle;
use Symfony\Bundle\TwigBundle\TwigBundle;
use Symfony\Bundle\WebProfilerBundle\WebProfilerBundle;
use Symfony\Bundle\WebServerBundle\WebServerBundle;
use Symfony\Component\Config\Loader\LoaderInterface;
use Symfony\Component\HttpKernel\Kernel;

class AppKernel extends Kernel
{
    public static $environments = ['test', 'dev', 'prod'];

    protected $name = 'pastebin';

    /**
     * @throws \RuntimeException
     */
    public function __construct(string $environment, bool $debug)
    {
        if (!in_array($environment, self::$environments, true)) {
            throw new \RuntimeException(sprintf(
                'Unsupported environment "%s", expected one of: %s',
                $environment,
                implode(', ', self::$environments)
            ));
        }

        parent::__construct($environment, $debug);
    }

    /**
     * @return \Symfony\Component\HttpKernel\Bundle\BundleInterface[]
     */
    public function registerBundles(): array
    {
        $bundles = [
            /* 3rd party bundles */
            new TwigBundle(),
            new FrameworkBundle(),
            new MonologBundle(),
        ];

        if (in_array($this->getEnvironment(), ['dev', 'test'], true)) {
            $bundles[] = new DebugBundle();
            $bundles[] = new WebServerBundle();
            $bundles[] = new WebProfilerBundle();
        }

        return $bundles;
    }

    public function registerContainerConfiguration(LoaderInterface $loader)
    {
        $config = sprintf('%s/../cfg/config.%s.yml', $this->rootDir, $this->getEnvironment());

        if (!is_readable($config)) {
            throw new \RuntimeException('Cannot read configuration file: ' . $config);
        }

        $loader->load($config);
    }

    public function getCacheDir(): string
    {
        return sprintf('%s/../var/%s/cache', $this->rootDir, $this->environment);
    }

    public function getLogDir(): string
    {
        return sprintf('%s/../var/%s/log', $this->rootDir, $this->environment);
    }

    public function getRootDir(): string
    {
        return __DIR__;
    }
}
