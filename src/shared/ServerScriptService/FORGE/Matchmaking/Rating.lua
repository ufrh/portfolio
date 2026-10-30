-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 8:15 PM CDT

local Rating = {} do
	-- Expected -> number
	-- Calculates the standard Elo expected score against one opponent rating.
	-- @param RatingA, number -> First rating.
	-- @param RatingB, number -> Opponent rating.
	function Rating.Expected(RatingA: number, RatingB: number)
		return 1 / (1 + 10 ^ ((RatingB - RatingA) / 400));
	end

	-- Elo -> number
	-- Calculates a new Elo rating from one result.
	-- @param Current, number -> Current player or team rating.
	-- @param Opponent, number -> Opponent rating.
	-- @param Score, number -> Result from 0 to 1.
	-- @param K, number? -> Optional K-factor.
	function Rating.Elo(Current: number, Opponent: number, Score: number, K: number?)
		local Factor = K or 32
		return Current + Factor * (Score - Rating.Expected(Current, Opponent));
	end

	-- Average -> number
	-- Returns the arithmetic mean of a numeric rating list.
	-- @param Values, table -> Numeric ratings.
	function Rating.Average(Values)
		if #Values == 0 then return 0 end

		local Total = 0
		for _, Value in ipairs(Values) do Total += Value end
		return Total / #Values;
	end

	-- WeightedAverage -> number
	-- Calculates a weighted rating average for party-sized tickets.
	-- @param Items, table -> Items with MMR/Skill and Size fields.
	function Rating.WeightedAverage(Items)
		local Total = 0
		local Weight = 0

		for _, Item in ipairs(Items) do
			local Size = tonumber(Item.Size) or 1
			Total += (tonumber(Item.MMR or Item.Skill) or 0) * Size
			Weight += Size
		end

		return Weight > 0 and Total / Weight or 0;
	end
end

return Rating;
