s/ c_float / c_double /g
s/ C_FLOAT / C_DOUBLE /g
s/ c_float[ ]*$/ c_double/g
s/ C_FLOAT[ ]*$/ C_DOUBLE/g
s/(c_float)/(c_double)/g
s/(C_FLOAT)/(C_DOUBLE)/g
s/_single[ ]*$/_double/g
s/_single,/_double,/g
s/_single /_double /g
s/_single(/_double(/g
s/E+0/D+0/g
s/real_bytes = 4/real_bytes = 8/g
