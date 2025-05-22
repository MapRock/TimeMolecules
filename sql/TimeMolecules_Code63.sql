USE [TimeSolution]
GO
--[START Code 63]
UPDATE dbo.EventSets
SET
[Description] = 'In poker, raises increase the current bet, requiring other
players to match or fold. A fold occurs when a player exits the round and forfeits
the pot. Calls match the current bet to stay in the round. Bets place a new wager to
initiate action. Checks allow passing the turn without betting, only if no previous
bets were made. These actions shape each round and influence strategies, leading to
the outcome of the hand.'
WHERE
EventSetKey = 0x281CE40AD3A51DE5CAC588793498CBCA;
--[END Code 63]
