import { BrowserOAuthClient } from '@atproto/oauth-client-browser';

// Derive the exact clientMetadata type the constructor expects so any
// upstream changes to the type will surface here at compile time.
type ClientMeta = NonNullable<
  ConstructorParameters<typeof BrowserOAuthClient>[0]['clientMetadata']
>;

export const CLIENT_METADATA: ClientMeta = {
  client_id: 'https://damienstanton.com/oauth-client-metadata.json',
  client_name: 'Synthetic Horizons',
  client_uri: 'https://damienstanton.com',
  logo_uri: 'https://damienstanton.com/pfp_round.png',
  redirect_uris: ['https://damienstanton.com/oauth-callback'],
  scope: 'atproto transition:generic',
  grant_types: ['authorization_code', 'refresh_token'],
  response_types: ['code'],
  token_endpoint_auth_method: 'none',
  application_type: 'web',
  dpop_bound_access_tokens: true,
};

export const HANDLE_RESOLVER = 'https://bsky.social';

export interface RecommendState {
  atUri: string;
  returnUrl: string;
}
