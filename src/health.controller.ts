import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { HealthResponseDto } from './dto/health-response.dto';

@ApiTags('Health')
@Controller('health')
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Verifica se o servidor está saudável.' })
  @ApiOkResponse({ type: HealthResponseDto })
  check() {
    const payload: HealthResponseDto = {
      status: 'ok',
      timestamp: Date.now(),
    };

    return payload;
  }
}
