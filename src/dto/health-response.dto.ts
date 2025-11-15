import { ApiProperty } from '@nestjs/swagger';

export class HealthResponseDto {
  @ApiProperty({ example: 'ok' })
  status: 'ok';

  @ApiProperty({
    description: 'Epoch timestamp em milissegundos',
    example: 1700000000000,
  })
  timestamp: number;
}
