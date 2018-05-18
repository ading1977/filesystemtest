import sys
lines = open(sys.argv[1]).readlines()
total = 0
c = 0
for line in lines:
  minute = int(line.split('m')[0])
  second = float(line.split('m')[1].split('s')[0])
  total = total + minute*60 + second
  c = c + 1
print total/c
