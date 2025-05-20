import statistics
import math

# Data sample
data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0, 6.2, 5.9, 6.8, 7.1, 7.3, 7.4, 7.5, 7.6, 7.8, 8.0, 8.1, 8.2]

"""
First, this is how standard deviation is calculated in two passes:
"""
# 1. First pass: calculate the mean
n = len(data)
mean = sum(data) / n

# 2. Second pass: calculate sum of squared deviations
sum_squared_diff = sum((x - mean) ** 2 for x in data)

# 3. Calculate variances and standard deviations
#    Population standard deviation (divide by n)
pop_std = math.sqrt(sum_squared_diff / n)

#    Sample standard deviation (divide by n-1)
sample_std = math.sqrt(sum_squared_diff / (n - 1))

print("Data:", data)
print(f"Mean: {mean:.5f}\n")
print("Manual two-pass calculation:")
print(f"  Population std (divide by n):   {pop_std:.5f}")
print(f"  Sample std    (divide by n-1): {sample_std:.5f}")



"""
Next, this is the value from the statistics module:
"""
# 1. Two-pass standard deviation
two_pass_sample = statistics.stdev(data)
two_pass_population = statistics.pstdev(data)

# 2. One-pass weighted standard deviation (uniform weights)
class OnePassWeighted:
    def __init__(self):
        self.total_weight = 0.0
        self.mean = 0.0
        self.S = 0.0

    def update(self, x, weight=1.0):
        W_new = self.total_weight + weight
        delta = x - self.mean
        mean_new = self.mean + (weight / W_new) * delta
        S_new = self.S + weight * delta * (x - mean_new)
        self.total_weight, self.mean, self.S = W_new, mean_new, S_new

    def variance(self, sample=True):
        if self.total_weight == 0:
            return 0.0
        denom = (self.total_weight - 1) if sample else self.total_weight
        return self.S / denom if denom > 0 else 0.0

    def std(self, sample=True):
        return (self.variance(sample)) ** 0.5

stats_one_pass = OnePassWeighted()
for x in data:
    stats_one_pass.update(x, weight=1.0)

one_pass_sample = stats_one_pass.std(sample=True)
one_pass_population = stats_one_pass.std(sample=False)

# Clear, labeled output
print("===== Standard Deviation Comparison =====")
print(f"Two-pass (sample, n-1):       {two_pass_sample:.5f}")
print(f"Two-pass (population, n):      {two_pass_population:.5f}")
print(f"One-pass (sample, n-1):        {one_pass_sample:.5f}")
print(f"One-pass (population, n):      {one_pass_population:.5f}")
