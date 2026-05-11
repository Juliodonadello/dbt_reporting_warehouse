select *
from (
    values
        ('Monthly', 1.0, 12.0),
        ('Weekly', 52.0 / 12.0, 52.0),
        ('Bi-weekly', 26.0 / 12.0, 26.0),
        ('Quarterly', 1.0 / 3.0, 4.0),
        ('Semi-annually', 1.0 / 6.0, 2.0),
        ('Annually', 1.0 / 12.0, 1.0),
        ('One Time', 1.0, 1.0)
) as frequency_factors(frequency, monthly_factor, annual_factor)

