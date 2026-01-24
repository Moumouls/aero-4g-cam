/**
 * Cloudflare Worker pour déclencher le workflow GitHub Actions
 * 
 * Variables d'environnement requises:
 * - GITHUB_TOKEN: Personal Access Token GitHub avec permissions 'repo' et 'workflow'
 * - API_SECRET: Secret pour sécuriser l'endpoint (optionnel mais recommandé)
 */

// Configuration hard-codée
const GITHUB_OWNER = 'Moumouls';
const GITHUB_REPO = 'aero-4g-cam';
const WORKFLOW_ID = 'generate-video.yml';
const BRANCH = 'dev';

export default {
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

      // Récupération du token GitHub
      const GITHUB_TOKEN = env.GITHUB_TOKEN;

      // Vérification du token
      if (!GITHUB_TOKEN) {
        return new Response(
          JSON.stringify({
            error: 'Configuration error',
            message: 'Missing GITHUB_TOKEN environment variable',
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
};
