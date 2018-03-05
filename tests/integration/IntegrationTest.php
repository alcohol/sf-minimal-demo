<?php declare(strict_types=1);

/*
 * (c) Rob Bast <rob.bast@gmail.com>
 *
 * For the full copyright and license information, please view
 * the LICENSE file that was distributed with this source code.
 */

namespace Paste;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;

abstract class IntegrationTest extends WebTestCase
{
    public static function createKernel(array $options = [])
    {
        $env = isset($options['environment'])
            ? $options['environment']
            : getenv('APP_ENV')
        ;

        $debug = isset($options['debug'])
            ? $options['debug']
            : (bool) (getenv('APP_DEBUG') ?? ('prod' !== getenv('APP_ENV')))
        ;

        return new Kernel($env, $debug);
    }

    public function extractLocationAndToken(Response $response): array
    {
        return [
            $response->headers->get('Location'),
            $response->headers->get('X-Paste-Token'),
        ];
    }
}
