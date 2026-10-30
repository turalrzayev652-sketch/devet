import { handleInvite } from '../../src/server/invite-handler.js';

export const onRequestGet = (context) => handleInvite(context);
