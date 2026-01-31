/**
 * Cloudflare Worker pour déclencher le workflow GitHub Actions
 * 
 * Variables d'environnement requises:
 * - GITHUB_TOKEN: Personal Access Token GitHub avec permissions 'repo' et 'workflow'
 * - API_SECRET: Secret pour sécuriser l'endpoint (optionnel mais recommandé)
 * 
 * Supporte:
 * - Requêtes HTTP POST manuelles
 * - Cloudflare Cron Triggers (scheduled)
 */

// Configuration hard-codée
const GITHUB_OWNER = 'Moumouls';
const GITHUB_REPO = 'aero-4g-cam';
const WORKFLOW_ID = 'generate-video.yml';
const BRANCH = 'master';

/**
 * Fonction pour déclencher le workflow GitHub
 */
async function triggerGitHubWorkflow(env) {
  // Récupération du token GitHub
  const GITHUB_TOKEN = env.GITHUB_TOKEN;

  // Vérification du token
  if (!GITHUB_TOKEN) {
    throw new Error('Missing GITHUB_TOKEN environment variable');
  }

  // Construction de l'URL de l'API GitHub
  const apiUrl = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_ID}/dispatches`;

  // Appel à l'API GitHub pour déclencher le workflow
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Accept': 'application/vnd.github+json',
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
      'User-Agent': 'Cloudflare-Worker',
    },
    body: JSON.stringify({
      ref: BRANCH,
    }),
  });

  return response;
}

export default {
  /**
   * Handler pour les requêtes HTTP
   */
  async fetch(request, env, ctx) {
    // Gestion CORS
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Réponse aux requêtes OPTIONS (preflight)
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: corsHeaders,
      });
    }

    // Vérification de la méthode HTTP
    if (request.method !== 'POST') {
      return new Response(
        JSON.stringify({
          error: 'Method not allowed',
          message: 'Only POST requests are accepted',
        }),
        {
          status: 405,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders,
          },
        }
      );
    }

    try {
      // Vérification du secret API (si configuré)
      if (env.API_SECRET) {
        const authHeader = request.headers.get('Authorization');
        const providedSecret = authHeader?.replace('Bearer ', '');

        if (providedSecret !== env.API_SECRET) {
          return new Response(
            JSON.stringify({
              error: 'Unauthorized',
              message: 'Invalid API secret',
            }),
            {
              status: 401,
              headers: {
                'Content-Type': 'application/json',
                ...corsHeaders,
              },
            }
          );
        }
      }

      // Appel à la fonction pour déclencher le workflow
      const response = await triggerGitHubWorkflow(env);

      // Vérification de la réponse GitHub
      if (response.status === 204) {
        return new Response(
          JSON.stringify({
            success: true,
            message: 'Workflow triggered successfully',
            workflow: WORKFLOW_ID,
            repository: `${GITHUB_OWNER}/${GITHUB_REPO}`,
            branch: BRANCH,
            timestamp: new Date().toISOString(),
          }),
          {
            status: 200,
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders,
            },
          }
        );
      } else {
        const errorText = await response.text();
        return new Response(
          JSON.stringify({
            error: 'GitHub API error',
            message: 'Failed to trigger workflow',
            status: response.status,
            details: errorText,
          }),
          {
            status: response.status,
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders,
            },
          }
        );
      }
    } catch (error) {
      return new Response(
        JSON.stringify({
          error: 'Internal server error',
          message: error.message,
        }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders,
          },
        }
      );
    }
  },

  /**
   * Handler pour les Cloudflare Cron Triggers
   * Configure dans le dashboard Cloudflare ou via wrangler.toml
   */
  async scheduled(event, env, ctx) {
    try {
      const scheduledDate = new Date(event.scheduledTime);
      console.log('Cron trigger received at:', scheduledDate.toISOString());

      const parisFormatter = new Intl.DateTimeFormat('en-GB', {
        timeZone: 'Europe/Paris',
        weekday: 'short',
        hour: 'numeric',
        hour12: false,
      });
      const parisParts = parisFormatter.formatToParts(scheduledDate);
      const parisWeekday = parisParts.find((part) => part.type === 'weekday')?.value;
      const parisHour = Number(parisParts.find((part) => part.type === 'hour')?.value);

      const weekendHours = new Set([9, 10, 11, 13, 14, 15, 16]);
      const weekdayHours = new Set([10, 14]);
      const isWeekend = parisWeekday === 'Sat' || parisWeekday === 'Sun';
      const shouldRun = Number.isFinite(parisHour) && (isWeekend ? weekendHours : weekdayHours).has(parisHour);

      if (!shouldRun) {
        console.log(
          `Skipping cron: Paris time ${parisWeekday} ${String(parisHour).padStart(2, '0')}h not in schedule.`
        );
        return;
      }

      // Appel à la fonction pour déclencher le workflow
      const response = await triggerGitHubWorkflow(env);

      // Vérification de la réponse GitHub
      if (response.status === 204) {
        console.log('Workflow triggered successfully via cron');
        console.log(`Repository: ${GITHUB_OWNER}/${GITHUB_REPO}`);
        console.log(`Workflow: ${WORKFLOW_ID}`);
        console.log(`Branch: ${BRANCH}`);
      } else {
        const errorText = await response.text();
        console.error('Failed to trigger workflow via cron');
        console.error(`Status: ${response.status}`);
        console.error(`Details: ${errorText}`);
        throw new Error(`GitHub API returned status ${response.status}: ${errorText}`);
      }
    } catch (error) {
      console.error('Error in scheduled trigger:', error.message);
      throw error; // Re-throw pour que Cloudflare enregistre l'échec
    }
  },
};
